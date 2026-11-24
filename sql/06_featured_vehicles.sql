/*==============================================================
  06_featured_vehicles.sql
  Featured vehicles: expose IsFeatured and add pub.usp_GetVehicles

  Safe to re-run (idempotent).

  STEP 1: Ensure stg.AuctionListRaw.IsFeatured exists
  STEP 2: analysis.vw_VehicleCard  — add IsFeatured (via RawId)
  STEP 3: pub.vw_Vehicle           — add IsFeatured
  STEP 4: pub.usp_GetVehicles      — paged / filtered vehicle list
  STEP 5: Grant EXECUTE to the web user (web_reader)

  How featuring works:
    Each dbo.AuctionVehicle row comes from exactly one raw PDF
    line (dbo.AuctionVehicle.RawId -> stg.AuctionListRaw.RawId).
    The featured flag lives on that raw line, so a vehicle is
    featured when its source line has IsFeatured = 1.
==============================================================*/
USE AuctionLab;
GO

/*--------------------------------------------------------------
  STEP 1: stg.AuctionListRaw.IsFeatured
  Fresh builds get this column from 01_create_auctionlab.sql;
  this adds it to databases created before that change.
  Steps 2-3 match the view definitions now in 04 and 05.
--------------------------------------------------------------*/
IF COL_LENGTH(N'stg.AuctionListRaw', N'IsFeatured') IS NULL
BEGIN
    ALTER TABLE stg.AuctionListRaw
        ADD IsFeatured BIT NOT NULL
            CONSTRAINT DF_AuctionListRaw_IsFeatured DEFAULT (0);
    PRINT 'Step 1: stg.AuctionListRaw.IsFeatured added.';
END
ELSE PRINT 'Step 1: stg.AuctionListRaw.IsFeatured already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 2: analysis.vw_VehicleCard
  Same as 04_analysis_views.sql, plus IsFeatured (last column).
--------------------------------------------------------------*/
CREATE OR ALTER VIEW analysis.vw_VehicleCard
AS
SELECT
    av.VehicleId,
    av.BatchId,
    av.SaleDate,

    -- VIN fields
    av.VinAsListed,
    av.VinAutoCorrected,
    av.VinCheckDigitOK,
    av.IsVerified,

    -- Resolved make / model / year
    -- Prefer NHTSA; fall back to what the parser found in the PDF
    ISNULL(vd.NhtsaMake,  av.Make)      AS Make,
    ISNULL(vd.NhtsaModel, av.Model)     AS Model,
    ISNULL(vd.NhtsaYear,  av.ListYear)  AS ModelYear,

    av.Color,
    vd.NhtsaBodyClass                   AS BodyClass,

    -- Raw parsed values (kept for transparency / debugging)
    av.Make                             AS ParsedMake,
    av.Model                            AS ParsedModel,
    av.ListYear                         AS ParsedYear,

    -- Raw NHTSA values
    vd.NhtsaMake                        AS NhtsaMake,
    vd.NhtsaModel                       AS NhtsaModel,
    vd.NhtsaYear                        AS NhtsaYear,
    vd.NhtsaErrorCode,

    -- Timestamps
    av.ParsedAt,
    vd.DecodedAt,

    -- Featured flag (set by the admin panel on the source raw line)
    CAST(ISNULL(r.IsFeatured, 0) AS BIT) AS IsFeatured
FROM dbo.AuctionVehicle AS av
LEFT JOIN dbo.VinDecode       AS vd ON vd.VehicleId = av.VehicleId
LEFT JOIN stg.AuctionListRaw  AS r  ON r.RawId      = av.RawId;
GO
PRINT 'Step 2: analysis.vw_VehicleCard updated (IsFeatured).';
GO

/*--------------------------------------------------------------
  STEP 3: pub.vw_Vehicle
  Same as 05_pub_schema.sql, plus IsFeatured (last column).
--------------------------------------------------------------*/
CREATE OR ALTER VIEW pub.vw_Vehicle
AS
SELECT
    vc.VehicleId,
    vc.Make,
    vc.Model,
    vc.ModelYear,
    vc.Color,
    vc.BodyClass,
    vc.VinAutoCorrected   AS Vin,
    vc.SaleDate,
    vc.IsVerified,
    vc.IsFeatured
FROM analysis.vw_VehicleCard AS vc
WHERE vc.Make IS NOT NULL;   -- hide any rows where parsing produced no make
GO
PRINT 'Step 3: pub.vw_Vehicle updated (IsFeatured).';
GO

/*--------------------------------------------------------------
  STEP 4: pub.usp_GetVehicles
  Paged, filtered vehicle list for GET /api/vehicles.
  Mirrors the API's current inline query:
    - exact Make match (case-insensitive: Make is upper-cased)
    - ModelYear range, exact BodyClass
    - ordered by VehicleId, OFFSET paging
  Adds an optional @IsFeatured filter (NULL = all vehicles).

  Returns two result sets:
    1. The page of vehicles
    2. TotalCount (matching rows across all pages)
--------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE pub.usp_GetVehicles
    @Make        NVARCHAR(100) = NULL,
    @YearMin     SMALLINT      = NULL,
    @YearMax     SMALLINT      = NULL,
    @BodyClass   NVARCHAR(100) = NULL,
    @IsFeatured  BIT           = NULL,
    @Page        INT           = 1,
    @PageSize    INT           = 20
AS
BEGIN
    SET NOCOUNT ON;

    -- Same limits the API applies
    IF @Page IS NULL OR @Page < 1          SET @Page = 1;
    IF @PageSize IS NULL OR @PageSize < 1  SET @PageSize = 20;
    IF @PageSize > 100                     SET @PageSize = 100;

    SET @Make      = NULLIF(UPPER(LTRIM(RTRIM(@Make))), N'');
    SET @BodyClass = NULLIF(LTRIM(RTRIM(@BodyClass)), N'');

    DECLARE @Offset INT = (@Page - 1) * @PageSize;

    -- 1. Page of vehicles
    SELECT
        v.VehicleId,
        v.Make,
        v.Model,
        v.ModelYear,
        v.Color,
        v.BodyClass,
        v.Vin,
        v.SaleDate,
        v.IsVerified,
        v.IsFeatured
    FROM pub.vw_Vehicle AS v
    WHERE (@Make       IS NULL OR v.Make       =  @Make)
      AND (@YearMin    IS NULL OR v.ModelYear  >= @YearMin)
      AND (@YearMax    IS NULL OR v.ModelYear  <= @YearMax)
      AND (@BodyClass  IS NULL OR v.BodyClass  =  @BodyClass)
      AND (@IsFeatured IS NULL OR v.IsFeatured =  @IsFeatured)
    ORDER BY v.VehicleId
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY
    OPTION (RECOMPILE);

    -- 2. Total matching rows
    SELECT COUNT(*) AS TotalCount
    FROM pub.vw_Vehicle AS v
    WHERE (@Make       IS NULL OR v.Make       =  @Make)
      AND (@YearMin    IS NULL OR v.ModelYear  >= @YearMin)
      AND (@YearMax    IS NULL OR v.ModelYear  <= @YearMax)
      AND (@BodyClass  IS NULL OR v.BodyClass  =  @BodyClass)
      AND (@IsFeatured IS NULL OR v.IsFeatured =  @IsFeatured)
    OPTION (RECOMPILE);
END
GO
PRINT 'Step 4: pub.usp_GetVehicles created / updated.';
GO

/*--------------------------------------------------------------
  STEP 5: Permissions
  web_reader (login auctionlab_web) already has SELECT on schema
  pub. Executing a procedure needs EXECUTE. All schemas are owned
  by dbo, so ownership chaining covers the underlying tables.
--------------------------------------------------------------*/
IF DATABASE_PRINCIPAL_ID(N'web_reader') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::pub.usp_GetVehicles TO web_reader;
    PRINT 'Step 5: EXECUTE on pub.usp_GetVehicles granted to web_reader.';
END
ELSE PRINT 'Step 5: web_reader not found, grant skipped.';
GO
