/*==============================================================
  07_admin_schema.sql
  Admin-only database objects used by /api/admin.

  Safe to re-run (idempotent).

  STEP 1: admin schema (owned by dbo)
  STEP 2: admin.usp_ToggleVehicleFeatured
  STEP 3: Grant EXECUTE to the web user (web_reader)

  Why a procedure:
    web_reader is read-only (SELECT on schema pub). Rather than
    giving it UPDATE on any table, it may only EXECUTE this one
    procedure. All schemas are owned by dbo, so ownership
    chaining lets the procedure update stg.AuctionListRaw.

  Depends on: 06_featured_vehicles.sql (IsFeatured column)
==============================================================*/
USE AuctionLab;
GO

/*--------------------------------------------------------------
  STEP 1: admin schema
--------------------------------------------------------------*/
IF SCHEMA_ID(N'admin') IS NULL
BEGIN
    EXEC (N'CREATE SCHEMA admin AUTHORIZATION dbo;');
    PRINT 'Step 1: admin schema created.';
END
ELSE PRINT 'Step 1: admin schema already exists, skipped.';
GO

/*--------------------------------------------------------------
  STEP 2: admin.usp_ToggleVehicleFeatured
  Flips IsFeatured for one vehicle. The flag lives on the
  vehicle's source line (dbo.AuctionVehicle.RawId ->
  stg.AuctionListRaw.RawId).

  Returns one row: VehicleId, IsFeatured (the NEW value).
  Returns no rows when the VehicleId does not exist.
--------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE admin.usp_ToggleVehicleFeatured
    @VehicleId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE r
    SET    r.IsFeatured = CASE WHEN r.IsFeatured = 1 THEN 0 ELSE 1 END
    OUTPUT @VehicleId       AS VehicleId,
           inserted.IsFeatured
    FROM   stg.AuctionListRaw AS r
    JOIN   dbo.AuctionVehicle AS av ON av.RawId = r.RawId
    WHERE  av.VehicleId = @VehicleId;
END
GO
PRINT 'Step 2: admin.usp_ToggleVehicleFeatured created / updated.';
GO

/*--------------------------------------------------------------
  STEP 3: Permissions
--------------------------------------------------------------*/
IF DATABASE_PRINCIPAL_ID(N'web_reader') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::admin.usp_ToggleVehicleFeatured TO web_reader;
    PRINT 'Step 3: EXECUTE on admin.usp_ToggleVehicleFeatured granted to web_reader.';
END
ELSE PRINT 'Step 3: web_reader not found, grant skipped.';
GO
