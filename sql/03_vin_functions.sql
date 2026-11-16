/*==============================================================
  03_vin_functions.sql

  Purpose : Adds VIN check-digit validation and the table that
            holds NHTSA decode results.  Also updates
            AuctionVehicle with the corrected VIN and check-digit
            flag for every row already parsed.

  Run order
    1. Run this script in SSMS (creates function + table).
    2. Run scripts\03_decode_vins.ps1 (calls NHTSA API, populates
       VinDecode, sets IsVerified).

  Target  : SQL Server 2022 or later (any edition)
  Rerun   : Safe. Objects created only if absent.
            Function uses CREATE OR ALTER.

  Contains no server names, logins, passwords, or file paths.
==============================================================*/

USE AuctionLab;
GO

/*--------------------------------------------------------------
  STEP 1: dbo.ufn_VinCheckDigit

  Implements the ISO 3779 / FMVSS 115 check-digit algorithm.

  Algorithm summary:
    1. Map each of the 17 VIN characters to a numeric value
       using the standard transliteration table.
    2. Multiply each value by the position weight.
    3. Sum all 17 products and take the result mod 11.
    4. If remainder = 10 the expected check character is 'X',
       otherwise it is the digit itself.
    5. Compare to the actual character at position 9.

  Returns 1 (valid) or 0 (invalid / illegal character present).
  I, O, and Q are banned from VINs by the standard; their
  presence returns 0 so the caller knows a correction is needed.
--------------------------------------------------------------*/
CREATE OR ALTER FUNCTION dbo.ufn_VinCheckDigit(@Vin CHAR(17))
RETURNS BIT
AS
BEGIN
    -- Must be exactly 17 characters
    IF LEN(RTRIM(@Vin)) <> 17 RETURN 0;

    -- 33 legal VIN characters and their transliterated values.
    -- Characters I (ascii 73), O (79), and Q (81) are absent
    -- by design; a VIN containing them returns 0.
    DECLARE @chars CHAR(33) = '0123456789ABCDEFGHJKLMNPRSTUVWXYZ';
    DECLARE @vals  CHAR(33) = '012345678912345678123457923456789';
    --                         0-9       A-H     J-N  P R S-Z

    DECLARE @sum INT = 0;
    DECLARE @i   INT = 1;
    DECLARE @ci  INT;   -- index of char in @chars (1-based)
    DECLARE @cv  INT;   -- numeric value of char
    DECLARE @cw  INT;   -- position weight

    WHILE @i <= 17
    BEGIN
        SET @ci = CHARINDEX(SUBSTRING(@Vin, @i, 1), @chars);
        IF @ci = 0 RETURN 0;   -- illegal character

        SET @cv = CAST(SUBSTRING(@vals, @ci, 1) AS INT);

        SET @cw = CASE @i
            WHEN  1 THEN 8   WHEN  2 THEN 7   WHEN  3 THEN 6
            WHEN  4 THEN 5   WHEN  5 THEN 4   WHEN  6 THEN 3
            WHEN  7 THEN 2   WHEN  8 THEN 10  WHEN  9 THEN 0
            WHEN 10 THEN 9   WHEN 11 THEN 8   WHEN 12 THEN 7
            WHEN 13 THEN 6   WHEN 14 THEN 5   WHEN 15 THEN 4
            WHEN 16 THEN 3   WHEN 17 THEN 2   ELSE 0
        END;

        SET @sum = @sum + (@cv * @cw);
        SET @i   = @i + 1;
    END

    DECLARE @rem      INT    = @sum % 11;
    DECLARE @expected CHAR(1) = CASE WHEN @rem = 10 THEN 'X'
                                     ELSE CAST(@rem AS CHAR(1)) END;

    RETURN CASE WHEN SUBSTRING(@Vin, 9, 1) = @expected THEN 1 ELSE 0 END;
END;
GO
PRINT 'Step 1: dbo.ufn_VinCheckDigit created / updated.';
GO

/*--------------------------------------------------------------
  STEP 2: dbo.VinDecode
  One row per VIN submitted to the NHTSA vPIC API.
  Populated by scripts\03_decode_vins.ps1.
--------------------------------------------------------------*/
IF OBJECT_ID(N'dbo.VinDecode', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VinDecode
    (
        DecodeId       INT IDENTITY(1,1) NOT NULL,
        VehicleId      INT               NOT NULL,
        VinSubmitted   CHAR(17)          NOT NULL,  -- VIN we sent to NHTSA
        NhtsaMake      NVARCHAR(100)     NULL,
        NhtsaModel     NVARCHAR(100)     NULL,
        NhtsaYear      SMALLINT          NULL,
        NhtsaBodyClass NVARCHAR(100)     NULL,
        NhtsaErrorCode NVARCHAR(20)      NULL,      -- '0' = clean decode
        NhtsaErrorText NVARCHAR(500)     NULL,
        DecodedAt      DATETIME2(0)      NOT NULL
            CONSTRAINT DF_VinDecode_DecodedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_VinDecode PRIMARY KEY CLUSTERED (DecodeId),
        CONSTRAINT FK_VinDecode_Vehicle
            FOREIGN KEY (VehicleId) REFERENCES dbo.AuctionVehicle (VehicleId)
    );
    PRINT 'Step 2: dbo.VinDecode created.';
END
ELSE PRINT 'Step 2: dbo.VinDecode already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 3: Back-fill VinAutoCorrected and VinCheckDigitOK
  for all rows in AuctionVehicle that have not been checked yet.

  VinAutoCorrected:
    Replace characters that are banned from VINs but are common
    OCR misreads:
      O (letter O) → 0 (zero)
      I (letter I) → 1 (one)
      Q             → 0 (zero)
    Set to the corrected value even when no change was needed
    so the PowerShell script always has a single column to read.

  VinCheckDigitOK:
    Run the check-digit function against VinAutoCorrected.
    A result of 1 means the 9th character validates correctly.
    A result of 0 may mean the VIN is transcribed incorrectly
    or was read off a damaged plate — the NHTSA API call will
    still attempt a decode and may return a partial match.
--------------------------------------------------------------*/
UPDATE dbo.AuctionVehicle
SET
    VinAutoCorrected = REPLACE(REPLACE(REPLACE(VinAsListed,
                            'O', '0'),
                            'I', '1'),
                            'Q', '0'),
    VinCheckDigitOK  = dbo.ufn_VinCheckDigit(
                            REPLACE(REPLACE(REPLACE(VinAsListed,
                                'O', '0'),
                                'I', '1'),
                                'Q', '0'))
WHERE VinCheckDigitOK IS NULL;

PRINT 'Step 3: AuctionVehicle updated — '
      + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows back-filled.';
GO

/*--------------------------------------------------------------
  CHECK: summary of VIN quality before NHTSA decode
--------------------------------------------------------------*/
SELECT
    COUNT(*)                                   AS TotalVehicles,
    SUM(CASE WHEN VinCheckDigitOK = 1 THEN 1 ELSE 0 END) AS CheckDigitOK,
    SUM(CASE WHEN VinCheckDigitOK = 0 THEN 1 ELSE 0 END) AS CheckDigitFail,
    SUM(CASE WHEN VinAsListed <> VinAutoCorrected
             THEN 1 ELSE 0 END)               AS VinsWithCorrections
FROM dbo.AuctionVehicle;
GO

/*--------------------------------------------------------------
  OPTIONAL RESET (leave commented out)
--------------------------------------------------------------*/
-- DROP TABLE IF EXISTS dbo.VinDecode;
-- DROP FUNCTION IF EXISTS dbo.ufn_VinCheckDigit;
-- UPDATE dbo.AuctionVehicle
--    SET VinAutoCorrected = NULL, VinCheckDigitOK = NULL, IsVerified = 0;
-- GO
