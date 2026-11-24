/*==============================================================
  04_analysis_views.sql

  Purpose : Creates the analysis schema and reporting views.
            These views are the data layer the Web API reads.
            No application code should query dbo tables directly.

  Run order : After 03_vin_functions.sql + 03_decode_vins.ps1
  Target    : SQL Server 2022 or later (any edition)
  Rerun     : Safe. Uses CREATE OR ALTER VIEW.
              Schema creation is guarded with IF NOT EXISTS.

  Views created
    analysis.vw_VehicleCard      -- one row per vehicle (API primary view)
    analysis.vw_MakeSummary      -- vehicle count by make
    analysis.vw_YearDistribution -- vehicle count by model year
    analysis.vw_BodyClassSummary -- vehicle count by NHTSA body class
    analysis.vw_BatchSummary     -- parse quality stats per batch

  Contains no server names, logins, passwords, or file paths.
==============================================================*/

USE AuctionLab;
GO

/*--------------------------------------------------------------
  STEP 1: Create analysis schema
--------------------------------------------------------------*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'analysis')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA analysis';
    PRINT 'Step 1: analysis schema created.';
END
ELSE PRINT 'Step 1: analysis schema already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 2: analysis.vw_VehicleCard
  One row per vehicle — the primary view the Web API queries.

  Make / Model / Year resolution:
    NHTSA values are authoritative when available.
    Parsed values are the fallback (came from the PDF text).

  The front end uses this view for:
    - The vehicle browse / search page
    - The vehicle detail page
    - Any filter that needs a full vehicle row
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
PRINT 'Step 2: analysis.vw_VehicleCard created / updated.';
GO

/*--------------------------------------------------------------
  STEP 3: analysis.vw_MakeSummary
  Aggregated counts by make.
  Used to populate the Make dropdown / filter on the front end.
  Ordered by vehicle count descending so the most common makes
  appear first.
--------------------------------------------------------------*/
CREATE OR ALTER VIEW analysis.vw_MakeSummary
AS
SELECT
    Make,
    COUNT(*)                                             AS VehicleCount,
    SUM(CASE WHEN IsVerified   = 1 THEN 1 ELSE 0 END)   AS VerifiedCount,
    MIN(ModelYear)                                       AS EarliestYear,
    MAX(ModelYear)                                       AS LatestYear
FROM analysis.vw_VehicleCard
GROUP BY Make;
GO
PRINT 'Step 3: analysis.vw_MakeSummary created / updated.';
GO

/*--------------------------------------------------------------
  STEP 4: analysis.vw_YearDistribution
  Aggregated counts by model year.
  Used for the year-range filter / slider on the front end.
  Excludes rows where ModelYear could not be determined.
--------------------------------------------------------------*/
CREATE OR ALTER VIEW analysis.vw_YearDistribution
AS
SELECT
    ModelYear,
    COUNT(*)                                             AS VehicleCount,
    SUM(CASE WHEN IsVerified = 1 THEN 1 ELSE 0 END)     AS VerifiedCount
FROM analysis.vw_VehicleCard
WHERE ModelYear IS NOT NULL
GROUP BY ModelYear;
GO
PRINT 'Step 4: analysis.vw_YearDistribution created / updated.';
GO

/*--------------------------------------------------------------
  STEP 5: analysis.vw_BodyClassSummary
  Aggregated counts by NHTSA body class (Sedan, SUV, Truck …).
  NULL body class (vehicle not decoded or class not returned)
  is shown as 'Unknown'.
  Used for the Body Class filter on the front end.
--------------------------------------------------------------*/
CREATE OR ALTER VIEW analysis.vw_BodyClassSummary
AS
SELECT
    ISNULL(BodyClass, N'Unknown')                        AS BodyClass,
    COUNT(*)                                             AS VehicleCount,
    SUM(CASE WHEN IsVerified = 1 THEN 1 ELSE 0 END)     AS VerifiedCount
FROM analysis.vw_VehicleCard
GROUP BY BodyClass;
GO
PRINT 'Step 5: analysis.vw_BodyClassSummary created / updated.';
GO

/*--------------------------------------------------------------
  STEP 6: analysis.vw_BatchSummary
  One row per auction batch — useful for the ops / admin side.
  Shows parse quality and VIN health at a glance.
--------------------------------------------------------------*/



CREATE OR ALTER VIEW analysis.vw_BatchSummary
AS
SELECT
    ab.BatchId,
    ab.SourceUrl,
    ab.SaleDate,
    ab.BatchStatus,
    ab.DownloadedAt,

    COUNT(av.VehicleId)                                       AS VehicleCount,
    SUM(CASE WHEN av.VinCheckDigitOK = 1  THEN 1 ELSE 0 END) AS CheckDigitOK,
    SUM(CASE WHEN av.VinCheckDigitOK = 0  THEN 1 ELSE 0 END) AS CheckDigitFail,
    SUM(CASE WHEN av.IsVerified       = 1  THEN 1 ELSE 0 END) AS Verified,
    SUM(CASE WHEN av.VinAsListed <> av.VinAutoCorrected
             THEN 1 ELSE 0 END)                               AS VinsWithOcrFix,
    (SELECT COUNT(*)
     FROM stg.AuctionListReject AS r
     WHERE r.BatchId = ab.BatchId)                            AS RejectCount
FROM dbo.AuctionBatch        AS ab
LEFT JOIN dbo.AuctionVehicle AS av ON av.BatchId = ab.BatchId
GROUP BY
    ab.BatchId,
    ab.SourceUrl,
    ab.SaleDate,
    ab.BatchStatus,
    ab.DownloadedAt;
GO

-- Verify
SELECT * FROM analysis.vw_BatchSummary;
GO



/*--------------------------------------------------------------
  CHECK 1: confirm all five views are present
--------------------------------------------------------------*/
SELECT
    s.name  AS SchemaName,
    o.name  AS ViewName,
    o.create_date,
    o.modify_date
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE s.name = N'analysis'
  AND o.type = N'V'
ORDER BY o.name;
GO

/*--------------------------------------------------------------
  CHECK 2: row counts for every view
--------------------------------------------------------------*/
SELECT 'vw_VehicleCard'     AS ViewName, COUNT(*) AS Rows FROM analysis.vw_VehicleCard
UNION ALL
SELECT 'vw_MakeSummary',                 COUNT(*)         FROM analysis.vw_MakeSummary
UNION ALL
SELECT 'vw_YearDistribution',            COUNT(*)         FROM analysis.vw_YearDistribution
UNION ALL
SELECT 'vw_BodyClassSummary',            COUNT(*)         FROM analysis.vw_BodyClassSummary
UNION ALL
SELECT 'vw_BatchSummary',                COUNT(*)         FROM analysis.vw_BatchSummary;
GO

/*--------------------------------------------------------------
  CHECK 3: sample from vw_VehicleCard
  Shows the top 10 vehicles with Make, Model, Year, BodyClass
--------------------------------------------------------------*/
SELECT TOP 10
    VehicleId,
    Make,
    Model,
    ModelYear,
    Color,
    BodyClass,
    IsVerified,
    VinCheckDigitOK
FROM analysis.vw_VehicleCard
ORDER BY VehicleId;
GO

/*--------------------------------------------------------------
  CHECK 4: make summary — most common makes in this batch
--------------------------------------------------------------*/
SELECT Make, VehicleCount, VerifiedCount, EarliestYear, LatestYear
FROM analysis.vw_MakeSummary
ORDER BY VehicleCount DESC;
GO

/*--------------------------------------------------------------
  OPTIONAL RESET (leave commented out)
--------------------------------------------------------------*/
-- DROP VIEW IF EXISTS analysis.vw_BatchSummary;
-- DROP VIEW IF EXISTS analysis.vw_BodyClassSummary;
-- DROP VIEW IF EXISTS analysis.vw_YearDistribution;
-- DROP VIEW IF EXISTS analysis.vw_MakeSummary;
-- DROP VIEW IF EXISTS analysis.vw_VehicleCard;
-- GO