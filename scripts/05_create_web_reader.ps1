# =============================================================
#  05_create_web_reader.ps1
#
#  Purpose : Creates the auctionlab_web SQL Server login and
#            maps it to a database user with SELECT-only access
#            to the pub schema.
#
#  Rerun   : Safe. Each block checks before creating.
#
#  Requires: config.ps1 in the parent folder.
#            WebReaderPassword must be set in config.ps1.
#
#  Contains no server names, passwords, or file paths.
# =============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot '..\config.ps1'
if (-not (Test-Path $configPath)) {
    Write-Error "config.ps1 not found."
    exit 1
}
. $configPath

# -- Step 1: Create the SQL Server login ----------------------
$createLoginSql = "IF NOT EXISTS ( " +
                  "    SELECT 1 FROM sys.server_principals " +
                  "    WHERE name = N'auctionlab_web' " +
                  ") " +
                  "BEGIN " +
                  "    CREATE LOGIN auctionlab_web " +
                  "    WITH PASSWORD = N'" + $WebReaderPassword.Replace("'","''") + "', " +
                  "    DEFAULT_DATABASE = AuctionLab, " +
                  "    CHECK_EXPIRATION = OFF, CHECK_POLICY = ON; " +
                  "    PRINT 'Login auctionlab_web created.'; " +
                  "END " +
                  "ELSE PRINT 'Login auctionlab_web already exists, skipped.';"

Invoke-Sqlcmd -ServerInstance $SqlInstance -Database master `
    -Query $createLoginSql -TrustServerCertificate
Write-Host "Step 1 done."

# -- Step 2: Create the database user -------------------------
$createUserSql = "IF NOT EXISTS ( " +
                 "    SELECT 1 FROM sys.database_principals " +
                 "    WHERE name = N'web_reader' " +
                 ") " +
                 "BEGIN " +
                 "    CREATE USER web_reader FOR LOGIN auctionlab_web; " +
                 "    PRINT 'User web_reader created.'; " +
                 "END " +
                 "ELSE PRINT 'User web_reader already exists, skipped.';"

Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $Database `
    -Query $createUserSql -TrustServerCertificate
Write-Host "Step 2 done."

# -- Step 3: Grant SELECT on pub schema -----------------------
$grantSql = "GRANT SELECT ON SCHEMA::pub TO web_reader;"

Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $Database `
    -Query $grantSql -TrustServerCertificate
Write-Host "Step 3 done: SELECT on pub schema granted to web_reader."

Write-Host "`nweb_reader can now SELECT from all pub.* views."
Write-Host "Connection string for the Web API:"
Write-Host "  Server=$SqlInstance;Database=$Database;User Id=auctionlab_web;Password=<from config>"