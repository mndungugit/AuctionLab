/*==============================================================
  02_parse_auction_batch.sql

  Purpose : Creates the tables that hold parsed vehicle data,
            seeds the make lookup, and creates the stored
            procedure that turns raw text lines into clean rows.
  Target  : SQL Server 2022 or later (any edition)
  Run as  : A login with permission to create objects in AuctionLab
  Rerun   : Safe. Tables are only created if absent.
            The stored procedure uses CREATE OR ALTER.

  After running this script, call the procedure for BatchId 1:
      EXEC dbo.usp_ParseAuctionBatch @BatchId = 1;

  Contains no server names, logins, passwords, or file paths.
==============================================================*/

USE AuctionLab;
GO

/*--------------------------------------------------------------
  STEP 1: dbo.MakeLookup
  Known vehicle makes.  Used to flag unrecognised makes after
  parsing; does not block insert.
--------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.MakeLookup', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MakeLookup
    (
        MakeId   SMALLINT     IDENTITY(1,1) NOT NULL,
        MakeName NVARCHAR(50) NOT NULL,
        CONSTRAINT PK_MakeLookup  PRIMARY KEY CLUSTERED (MakeId),
        CONSTRAINT UQ_MakeLookup  UNIQUE (MakeName)
    );
    PRINT 'Step 1: dbo.MakeLookup created.';
END
ELSE PRINT 'Step 1: dbo.MakeLookup already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 2: Seed dbo.MakeLookup
  Only inserts makes that are not already present.
--------------------------------------------------------------*/
INSERT INTO dbo.MakeLookup (MakeName)
SELECT v.MakeName
FROM (VALUES
    (N'ACURA'),       (N'ALFA ROMEO'),  (N'ASTON MARTIN'), (N'AUDI'),
    (N'BENTLEY'),     (N'BMW'),         (N'BUICK'),         (N'CADILLAC'),
    (N'CHEVROLET'),   (N'CHRYSLER'),    (N'DODGE'),         (N'FERRARI'),
    (N'FIAT'),        (N'FORD'),        (N'GENESIS'),       (N'GMC'),
    (N'HONDA'),       (N'HYUNDAI'),     (N'INFINITI'),      (N'JAGUAR'),
    (N'JEEP'),        (N'KIA'),         (N'LAMBORGHINI'),   (N'LANDROVER'),
    (N'LEXUS'),       (N'LINCOLN'),     (N'MASERATI'),      (N'MAZDA'),
    (N'MERCEDES-BENZ'),(N'MINI'),       (N'MITSUBISHI'),    (N'NISSAN'),
    (N'OLDSMOBILE'),  (N'PONTIAC'),     (N'PORSCHE'),       (N'RAM'),
    (N'ROLLS-ROYCE'), (N'SATURN'),      (N'SCION'),         (N'SUBARU'),
    (N'SUZUKI'),      (N'TESLA'),       (N'TOYOTA'),        (N'VOLKSWAGEN'),
    (N'VOLVO')
) AS v(MakeName)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.MakeLookup m WHERE m.MakeName = v.MakeName
);
PRINT 'Step 2: MakeLookup seeded (' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows inserted).';
GO

/*--------------------------------------------------------------
  STEP 3: dbo.AuctionVehicle
  One row per vehicle parsed from the auction list.
  VIN correction and check-digit validation are added in Step 5.
--------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.AuctionVehicle', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuctionVehicle
    (
        VehicleId        INT IDENTITY(1,1) NOT NULL,
        BatchId          INT               NOT NULL,
        RawId            BIGINT            NOT NULL,
        SaleDate         DATE              NULL,        -- from footer
        VinAsListed      CHAR(17)          NOT NULL,
        VinAutoCorrected CHAR(17)          NULL,        -- set in Step 5 if O/I/Q corrected
        VinCheckDigitOK  BIT               NULL,        -- set in Step 5
        IsVerified       BIT               NOT NULL
            CONSTRAINT DF_AuctionVehicle_IsVerified DEFAULT (0),
        Make             NVARCHAR(50)      NULL,
        Model            NVARCHAR(100)     NULL,
        ListYear         SMALLINT          NULL,
        Color            NVARCHAR(50)      NULL,
        ParsedAt         DATETIME2(0)      NOT NULL
            CONSTRAINT DF_AuctionVehicle_ParsedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_AuctionVehicle PRIMARY KEY CLUSTERED (VehicleId),
        CONSTRAINT FK_AuctionVehicle_Batch
            FOREIGN KEY (BatchId) REFERENCES dbo.AuctionBatch (BatchId),
        CONSTRAINT FK_AuctionVehicle_Raw
            FOREIGN KEY (RawId)   REFERENCES stg.AuctionListRaw (RawId)
    );
    PRINT 'Step 3: dbo.AuctionVehicle created.';
END
ELSE PRINT 'Step 3: dbo.AuctionVehicle already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 4: stg.AuctionListReject
  Lines the parser could not fully parse (e.g. year not found).
  Review after each run; a row here may mean a new list format.
--------------------------------------------------------------*/
IF OBJECT_ID(N'stg.AuctionListReject', N'U') IS NULL
BEGIN
    CREATE TABLE stg.AuctionListReject
    (
        RejectId     INT IDENTITY(1,1) NOT NULL,
        BatchId      INT               NOT NULL,
        RawId        BIGINT            NOT NULL,
        LineNumber   INT               NOT NULL,
        RawText      NVARCHAR(500)     NOT NULL,
        RejectReason NVARCHAR(200)     NOT NULL,
        RejectedAt   DATETIME2(0)      NOT NULL
            CONSTRAINT DF_AuctionListReject_RejectedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_AuctionListReject PRIMARY KEY CLUSTERED (RejectId)
    );
    PRINT 'Step 4: stg.AuctionListReject created.';
END
ELSE PRINT 'Step 4: stg.AuctionListReject already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 5: dbo.usp_ParseAuctionBatch

  Parameters
    @BatchId INT  - which batch to parse
    @Reparse BIT  - 1 = delete existing rows and reparse
                    0 (default) = skip if already parsed

  How the parser works
  --------------------
  Line classification (after LTRIM/RTRIM):
    Blank   - empty line; skipped
    Vehicle - first 17 chars are all [A-Z0-9] AND char 18 is a
              space; this is a VIN line
    Footer  - everything else (address, disclaimer, sale date)

  Vehicle line parsing:
    VIN       = LEFT(line, 17)
    Remainder = everything after VIN, left-trimmed
    Year      - scan Remainder for a 4-digit token in the
                decade ranges 198x, 199x, 200x, 201x, 202x
                using two PATINDEX calls; take the leftmost hit
    MakeModel = Remainder to the left of the year token
    Color     = Remainder to the right of the year token
    Make      = first space-delimited word of MakeModel
    Model     = rest of MakeModel after Make

  Sale date:
    All raw lines for the batch are concatenated and searched
    for the first MM/DD/YYYY date pattern.

  Rejects:
    Vehicle-pattern lines where the year cannot be found are
    inserted into stg.AuctionListReject for review.
--------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.usp_ParseAuctionBatch
    @BatchId INT,
    @Reparse BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- --------------------------------------------------------
    -- Guard: batch must exist
    -- --------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.AuctionBatch WHERE BatchId = @BatchId)
    BEGIN
        RAISERROR('BatchId %d not found in dbo.AuctionBatch.', 16, 1, @BatchId);
        RETURN;
    END

    -- --------------------------------------------------------
    -- Guard: skip if already parsed (unless reparse requested)
    -- --------------------------------------------------------
    IF @Reparse = 0
       AND EXISTS (SELECT 1 FROM dbo.AuctionVehicle WHERE BatchId = @BatchId)
    BEGIN
        PRINT 'BatchId ' + CAST(@BatchId AS VARCHAR(10)) +
              ' already parsed. Use @Reparse = 1 to reparse.';
        RETURN;
    END

    -- --------------------------------------------------------
    -- Clean up previous results if reparsing
    -- --------------------------------------------------------
    IF @Reparse = 1
    BEGIN
        DELETE FROM stg.AuctionListReject WHERE BatchId = @BatchId;
        DELETE FROM dbo.AuctionVehicle    WHERE BatchId = @BatchId;
        PRINT 'Reparse: previous rows removed for BatchId '
              + CAST(@BatchId AS VARCHAR(10));
    END

    -- --------------------------------------------------------
    -- A. Find sale date in footer
    --    Concatenate all lines and look for MM/DD/YYYY pattern
    -- --------------------------------------------------------
    DECLARE @SaleDate    DATE         = NULL;
    DECLARE @FooterText  NVARCHAR(MAX) = NULL;
    DECLARE @DatePos     INT;

    SELECT @FooterText = STRING_AGG(LTRIM(RTRIM(RawText)), N' ')
                         WITHIN GROUP (ORDER BY LineNumber)
    FROM stg.AuctionListRaw
    WHERE BatchId = @BatchId;

    SET @DatePos = PATINDEX(
        N'%[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9]%',
        @FooterText
    );
    IF @DatePos > 0
        SET @SaleDate = TRY_CAST(SUBSTRING(@FooterText, @DatePos, 10) AS DATE);

    PRINT 'Sale date: '
          + ISNULL(CONVERT(VARCHAR(10), @SaleDate, 101), 'not found');

    -- --------------------------------------------------------
    -- B. Parse vehicle lines
    --
    --    CTE chain:
    --    Cleaned       - trim whitespace
    --    VehicleOnly   - keep only vehicle-pattern lines
    --    WithRemainder - extract VIN and the rest of the line
    --    WithYearPos   - find leftmost decade-range year token
    --    Parsed        - split into MakeModel / Year / Color
    --    Split         - split MakeModel into Make + Model
    -- --------------------------------------------------------
    ;WITH Cleaned AS (
        SELECT
            RawId,
            BatchId,
            LineNumber,
            LTRIM(RTRIM(RawText)) AS Line
        FROM stg.AuctionListRaw
        WHERE BatchId = @BatchId
    ),
    VehicleOnly AS (
        SELECT
            RawId,
            BatchId,
            LineNumber,
            LEFT(Line, 17)              AS VinAsListed,
            LTRIM(SUBSTRING(Line, 19, 500)) AS Remainder
        FROM Cleaned
        WHERE LEN(Line) >= 18
          AND SUBSTRING(Line, 18, 1) = N' '
          AND LEFT(Line, 17) NOT LIKE N'%[^A-Z0-9]%'
    ),
    WithYearPos AS (
        SELECT
            RawId,
            BatchId,
            LineNumber,
            VinAsListed,
            Remainder,
            -- Find the leftmost 4-digit year token (1980-2029).
            -- NULLIF converts a "not found" (0) to NULL so MIN ignores it.
            -- The two patterns cover 1980s/1990s and 2000s/2010s/2020s
            -- without matching common model numbers like 1500 or 300.
            (SELECT MIN(p.pos)
             FROM (VALUES
                 (NULLIF(PATINDEX(N'% 1[9][0-9][0-9] %',
                         N' ' + Remainder + N' '), 0)),
                 (NULLIF(PATINDEX(N'% 20[0-2][0-9] %',
                         N' ' + Remainder + N' '), 0))
             ) AS p(pos)) AS YearPos
        FROM VehicleOnly
    ),
    Parsed AS (
        SELECT
            RawId,
            BatchId,
            LineNumber,
            VinAsListed,
            YearPos,
            -- MakeModel = everything to the left of the year
            CASE WHEN YearPos > 0
                 THEN RTRIM(LEFT(Remainder, YearPos - 1))
                 ELSE Remainder
            END AS MakeModel,
            -- Year = the 4-digit token at YearPos
            CASE WHEN YearPos > 0
                 THEN TRY_CAST(SUBSTRING(Remainder, YearPos, 4) AS SMALLINT)
                 ELSE NULL
            END AS ListYear,
            -- Color = everything to the right of the year
            CASE WHEN YearPos > 0
                 THEN LTRIM(SUBSTRING(Remainder, YearPos + 5, 500))
                 ELSE NULL
            END AS Color
        FROM WithYearPos
    ),
    Split AS (
        SELECT
            RawId,
            BatchId,
            LineNumber,
            VinAsListed,
            ListYear,
            Color,
            YearPos,
            -- Make = first space-delimited word of MakeModel
            CASE WHEN CHARINDEX(N' ', MakeModel) > 0
                 THEN LEFT(MakeModel, CHARINDEX(N' ', MakeModel) - 1)
                 ELSE MakeModel
            END AS Make,
            -- Model = everything after Make
            CASE WHEN CHARINDEX(N' ', MakeModel) > 0
                 THEN LTRIM(SUBSTRING(MakeModel,
                            CHARINDEX(N' ', MakeModel) + 1, 500))
                 ELSE NULL
            END AS Model
        FROM Parsed
    )
    -- Insert vehicle rows
    INSERT INTO dbo.AuctionVehicle
        (BatchId, RawId, SaleDate, VinAsListed, Make, Model, ListYear, Color)
    SELECT
        BatchId,
        RawId,
        @SaleDate,
        VinAsListed,
        Make,
        Model,
        ListYear,
        Color
    FROM Split
    WHERE YearPos > 0;   -- only fully parsed rows; rejects handled below

    DECLARE @VehicleCount INT = @@ROWCOUNT;
    PRINT 'Vehicles inserted: ' + CAST(@VehicleCount AS VARCHAR(10));

    -- --------------------------------------------------------
    -- C. Send vehicle-pattern lines where year was not found
    --    to stg.AuctionListReject for manual review
    -- --------------------------------------------------------
    ;WITH Cleaned AS (
        SELECT
            RawId, BatchId, LineNumber,
            LTRIM(RTRIM(RawText)) AS Line
        FROM stg.AuctionListRaw
        WHERE BatchId = @BatchId
    ),
    VehicleOnly AS (
        SELECT RawId, BatchId, LineNumber, Line,
               LTRIM(SUBSTRING(Line, 19, 500)) AS Remainder
        FROM Cleaned
        WHERE LEN(Line) >= 18
          AND SUBSTRING(Line, 18, 1) = N' '
          AND LEFT(Line, 17) NOT LIKE N'%[^A-Z0-9]%'
    ),
    NoYear AS (
        SELECT RawId, BatchId, LineNumber, Line
        FROM VehicleOnly
        WHERE (SELECT MIN(p.pos)
               FROM (VALUES
                   (NULLIF(PATINDEX(N'% 1[9][0-9][0-9] %',
                           N' ' + Remainder + N' '), 0)),
                   (NULLIF(PATINDEX(N'% 20[0-2][0-9] %',
                           N' ' + Remainder + N' '), 0))
               ) AS p(pos)) IS NULL
    )
    INSERT INTO stg.AuctionListReject
        (BatchId, RawId, LineNumber, RawText, RejectReason)
    SELECT
        BatchId,
        RawId,
        LineNumber,
        Line,
        N'Vehicle pattern matched but year (1980-2029) not found in remainder'
    FROM NoYear;

    DECLARE @RejectCount INT = @@ROWCOUNT;
    PRINT 'Rejects inserted: ' + CAST(@RejectCount AS VARCHAR(10));

    -- --------------------------------------------------------
    -- D. Update AuctionBatch
    -- --------------------------------------------------------
    UPDATE dbo.AuctionBatch
    SET SaleDate    = @SaleDate,
        BatchStatus = N'Parsed'
    WHERE BatchId   = @BatchId;

    PRINT 'BatchStatus set to Parsed. Done.';
END;
GO

/*--------------------------------------------------------------
  CHECK: confirm all objects are in place
--------------------------------------------------------------*/
SELECT
    s.name       AS SchemaName,
    o.name       AS ObjectName,
    o.type_desc  AS ObjectType
FROM sys.objects  AS o
JOIN sys.schemas  AS s ON s.schema_id = o.schema_id
WHERE (s.name IN (N'dbo', N'stg') AND o.type = N'U')
   OR (s.name = N'dbo' AND o.type = N'P'
       AND o.name = N'usp_ParseAuctionBatch')
ORDER BY o.type_desc, s.name, o.name;
GO

/*--------------------------------------------------------------
  OPTIONAL RESET (leave commented out)
  Run these only if you need to drop and recreate everything.
--------------------------------------------------------------*/
-- DROP PROCEDURE IF EXISTS dbo.usp_ParseAuctionBatch;
-- DROP TABLE IF EXISTS stg.AuctionListReject;
-- DROP TABLE IF EXISTS dbo.AuctionVehicle;
-- DROP TABLE IF EXISTS dbo.MakeLookup;
-- GO
