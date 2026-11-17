/*==============================================================
  05_pub_schema.sql

  Purpose : Creates the pub schema and its customer-facing views.
            The Web API reads ONLY from this schema.
            It never touches dbo, stg, or analysis directly.

  Run order : After 04_analysis_views.sql
  Target    : SQL Server 2022 or later (any edition)
  Rerun     : Safe. Uses CREATE OR ALTER VIEW.

  Views created
    pub.vw_Vehicle      -- one row per vehicle (browse / detail page)
    pub.vw_MakeList     -- distinct makes + counts  (filter dropdown)
    pub.vw_YearRange    -- min + max model year     (slider bounds)
    pub.vw_BodyClassList-- distinct body classes    (filter dropdown)

  After running this script, run scripts\05_create_web_reader.ps1
  to create the read-only SQL login that the Web API uses.

  Contains no server names, logins, passwords, or file paths.
==============================================================*/

USE AuctionLab;
GO

/*--------------------------------------------------------------
  STEP 1: Create pub schema
--------------------------------------------------------------*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'pub')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA pub';
    PRINT 'Step 1: pub schema created.';
END
ELSE PRINT 'Step 1: pub schema already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 2: pub.vw_Vehicle
  The main customer-facing view.

  What it exposes:
    - VehicleId       : stable ID for the detail page URL  (/vehicle/42)
    - Make / Model / ModelYear / Color / BodyClass
    - Vin             : corrected VIN so customers can run their own
                        history check (CARFAX, AutoCheck, etc.)
    - SaleDate        : the auction date this vehicle appeared on
    - IsVerified      : 1 = NHTSA confirmed the VIN; front end can
                        show a "Verified" badge

  What it deliberately omits:
    - Internal batch / raw IDs
    - VinAsListed (the uncorrected OCR value)
    - ParsedAt / DecodedAt (internal timestamps)
    - NHTSA error codes (internal quality signal)
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
    vc.IsVerified
FROM analysis.vw_VehicleCard AS vc
WHERE vc.Make IS NOT NULL;   -- hide any rows where parsing produced no make
GO
PRINT 'Step 2: pub.vw_Vehicle created / updated.';
GO

/*--------------------------------------------------------------
  STEP 3: pub.vw_MakeList
  Distinct makes with vehicle counts.
  Powers the Make filter dropdown on the browse page.
  Ordered alphabetically so the front end can render as-is.
--------------------------------------------------------------*/
CREATE OR ALTER VIEW pub.vw_MakeList
AS
SELECT
    Make,
    VehicleCount,
    EarliestYear,
    LatestYear
FROM analysis.vw_MakeSummary
WHERE Make IS NOT NULL;
GO
PRINT 'Step 3: pub.vw_MakeList created / updated.';
GO

/*--------------------------------------------------------------
  STEP 4: pub.vw_YearRange
  Single row: the earliest and latest model year in the inventory.
  Powers the min/max bounds of the year-range slider.
--------------------------------------------------------------*/
CREATE OR ALTER VIEW pub.vw_YearRange
AS
SELECT
    MIN(ModelYear) AS MinYear,
    MAX(ModelYear) AS MaxYear,
    COUNT(*)       AS TotalVehicles
FROM pub.vw_Vehicle
WHERE ModelYear IS NOT NULL;
GO
PRINT 'Step 4: pub.vw_YearRange created / updated.';
GO

/*--------------------------------------------------------------
  STEP 5: pub.vw_BodyClassList
  Distinct body classes with vehicle counts.
  Powers the Body Type filter on the browse page.
--------------------------------------------------------------*/
CREATE OR ALTER VIEW pub.vw_BodyClassList
AS
SELECT
    BodyClass,
    VehicleCount
FROM analysis.vw_BodyClassSummary;
GO
PRINT 'Step 5: pub.vw_BodyClassList created / updated.';
GO

/*--------------------------------------------------------------
  CHECK 1: confirm all four pub views are present
--------------------------------------------------------------*/
SELECT
    s.name  AS SchemaName,
    o.name  AS ViewName
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE s.name = N'pub'
  AND o.type = N'V'
ORDER BY o.name;
GO

/*--------------------------------------------------------------
  CHECK 2: row counts
--------------------------------------------------------------*/
SELECT 'pub.vw_Vehicle'       AS ViewName, COUNT(*) AS Rows FROM pub.vw_Vehicle
UNION ALL
SELECT 'pub.vw_MakeList',                  COUNT(*)         FROM pub.vw_MakeList
UNION ALL
SELECT 'pub.vw_YearRange',                 COUNT(*)         FROM pub.vw_YearRange
UNION ALL
SELECT 'pub.vw_BodyClassList',             COUNT(*)         FROM pub.vw_BodyClassList;
GO

/*--------------------------------------------------------------
  CHECK 3: sample vehicle rows — this is what the API returns
--------------------------------------------------------------*/
SELECT TOP 10
    VehicleId,
    Make,
    Model,
    ModelYear,
    Color,
    BodyClass,
    Vin,
    SaleDate,
    IsVerified
FROM pub.vw_Vehicle
ORDER BY VehicleId;
GO

/*--------------------------------------------------------------
  CHECK 4: make list — verify counts look right
--------------------------------------------------------------*/
SELECT Make, VehicleCount, EarliestYear, LatestYear
FROM pub.vw_MakeList
ORDER BY VehicleCount DESC;
GO

/*--------------------------------------------------------------
  CHECK 5: year range — single row for the slider
--------------------------------------------------------------*/
SELECT MinYear, MaxYear, TotalVehicles FROM pub.vw_YearRange;
GO

/*--------------------------------------------------------------
  OPTIONAL RESET (leave commented out)
--------------------------------------------------------------*/
-- DROP VIEW IF EXISTS pub.vw_BodyClassList;
-- DROP VIEW IF EXISTS pub.vw_YearRange;
-- DROP VIEW IF EXISTS pub.vw_MakeList;
-- DROP VIEW IF EXISTS pub.vw_Vehicle;
-- GO
