# =============================================================
#  03_decode_vins.ps1
#
#  Purpose : Call the free NHTSA vPIC API for every VIN in
#            dbo.AuctionVehicle, store the decoded details in
#            dbo.VinDecode, and mark fully-decoded vehicles as
#            IsVerified = 1.
#
#  Rerun   : Safe. Skips any VehicleId that already has a row
#            in dbo.VinDecode.
#
#  Requires: config.ps1 in the parent folder (one level up),
#            SqlServer PowerShell module.
#
#  NHTSA vPIC API is free and requires no API key:
#    https://vpic.nhtsa.dot.gov/api/
#
#  Contains no server names, passwords, or file paths.
#  All connection values come from config.ps1 (git-ignored).
# =============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------
# 1. Load config
# ------------------------------------------------------------------
$configPath = Join-Path $PSScriptRoot '..\config.ps1'
if (-not (Test-Path $configPath)) {
    Write-Error "config.ps1 not found. Copy config.example.ps1 and fill in your values."
    exit 1
}
. $configPath

# ------------------------------------------------------------------
# 2. Set up logging
# ------------------------------------------------------------------
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile   = Join-Path $LogDir "decode_$timestamp.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

function Write-Log {
    param([string]$msg)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-Log '=== 03_decode_vins.ps1 started ==='

# ------------------------------------------------------------------
# 3. Get VINs that have not been decoded yet
#    Uses VinAutoCorrected (I/O/Q already fixed by SQL script).
# ------------------------------------------------------------------
$getVinsSql = "SELECT v.VehicleId, v.VinAutoCorrected AS VinToSubmit, v.VinCheckDigitOK " +
              "FROM dbo.AuctionVehicle v " +
              "WHERE NOT EXISTS ( " +
              "    SELECT 1 FROM dbo.VinDecode d WHERE d.VehicleId = v.VehicleId " +
              ") " +
              "ORDER BY v.VehicleId;"

$vehicles = Invoke-Sqlcmd `
    -ServerInstance $SqlInstance `
    -Database $Database `
    -Query $getVinsSql `
    -TrustServerCertificate

if ($vehicles.Count -eq 0) {
    Write-Log 'All VINs already decoded. Nothing to do.'
    Write-Log '=== Script finished (no-op) ==='
    exit 0
}

Write-Log "VINs to decode: $($vehicles.Count)"

# ------------------------------------------------------------------
# 4. Decode each VIN via NHTSA vPIC API
# ------------------------------------------------------------------
$nhtsaBase  = 'https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVin'
$okCount    = 0
$errorCount = 0

foreach ($row in $vehicles) {
    $vehicleId = $row.VehicleId
    $vin       = $row.VinToSubmit.Trim()

    Write-Log "VehicleId $vehicleId  VIN $vin"

    # -- Call NHTSA API ------------------------------------------------
    try {
        $url      = "$nhtsaBase/$vin" + '?format=json'
        $response = Invoke-RestMethod -Uri $url -UseBasicParsing
        $results  = $response.Results
    }
    catch {
        Write-Log "  ERROR calling NHTSA for VIN $vin : $_"
        $errorCount++
        Start-Sleep -Milliseconds 500
        continue
    }

    # -- Extract fields from Results array ----------------------------
    function Get-NhtsaValue {
        param([array]$Results, [string]$VariableName)
        $val = ($Results | Where-Object { $_.Variable -eq $VariableName }).Value
        if ([string]::IsNullOrWhiteSpace($val) -or $val -eq 'Not Applicable') {
            return $null
        }
        return $val.Trim()
    }

    $nhtsaMake      = Get-NhtsaValue $results 'Make'
    $nhtsaModel     = Get-NhtsaValue $results 'Model'
    $nhtsaYearStr   = Get-NhtsaValue $results 'Model Year'
    $nhtsaBodyClass = Get-NhtsaValue $results 'Body Class'
    $nhtsaErrorCode = Get-NhtsaValue $results 'Error Code'
    $nhtsaErrorText = Get-NhtsaValue $results 'Additional Error Text'

    $nhtsaYear = $null
    if ($nhtsaYearStr -match '^\d{4}$') { $nhtsaYear = [int]$nhtsaYearStr }

    Write-Log "  Make=$nhtsaMake  Model=$nhtsaModel  Year=$nhtsaYearStr  Error=$nhtsaErrorCode"

    # -- Helper: escape single quotes for SQL -------------------------
    function Escape-Sql { param([string]$s)
        if ($null -eq $s) { return 'NULL' }
        return "N'" + $s.Replace("'", "''") + "'"
    }

    $sqlMake      = Escape-Sql $nhtsaMake
    $sqlModel     = Escape-Sql $nhtsaModel
    $sqlBodyClass = Escape-Sql $nhtsaBodyClass
    $sqlErrorCode = Escape-Sql $nhtsaErrorCode
    $sqlErrorText = Escape-Sql $nhtsaErrorText
    $sqlYear      = if ($null -eq $nhtsaYear) { 'NULL' } else { $nhtsaYear.ToString() }

    # -- Insert into dbo.VinDecode ------------------------------------
    $insertSql = "INSERT INTO dbo.VinDecode " +
                 "    (VehicleId, VinSubmitted, NhtsaMake, NhtsaModel, " +
                 "     NhtsaYear, NhtsaBodyClass, NhtsaErrorCode, NhtsaErrorText) " +
                 "VALUES " +
                 "    ($vehicleId, N'$vin', $sqlMake, $sqlModel, " +
                 "     $sqlYear, $sqlBodyClass, $sqlErrorCode, $sqlErrorText);"

    try {
        Invoke-Sqlcmd `
            -ServerInstance $SqlInstance `
            -Database $Database `
            -Query $insertSql `
            -TrustServerCertificate | Out-Null
    }
    catch {
        Write-Log "  ERROR inserting VinDecode row for VehicleId $vehicleId : $_"
        $errorCount++
        Start-Sleep -Milliseconds 500
        continue
    }

    # -- Mark IsVerified if NHTSA returned a clean decode -------------
    if ($nhtsaErrorCode -eq '0') {
        $updateSql = "UPDATE dbo.AuctionVehicle SET IsVerified = 1 WHERE VehicleId = $vehicleId;"
        Invoke-Sqlcmd `
            -ServerInstance $SqlInstance `
            -Database $Database `
            -Query $updateSql `
            -TrustServerCertificate | Out-Null
        $okCount++
    }

    Start-Sleep -Milliseconds 200
}

# ------------------------------------------------------------------
# 5. Summary
# ------------------------------------------------------------------
Write-Log '---'
Write-Log "Decoded  : $($vehicles.Count)"
Write-Log "Verified (ErrorCode = 0) : $okCount"
Write-Log "Errors   : $errorCount"
Write-Log '=== 03_decode_vins.ps1 finished ==='

$checkSql = "SELECT COUNT(*) AS TotalVehicles, " +
            "SUM(CASE WHEN IsVerified = 1 THEN 1 ELSE 0 END) AS Verified, " +
            "SUM(CASE WHEN VinCheckDigitOK = 1 THEN 1 ELSE 0 END) AS CheckDigitOK " +
            "FROM dbo.AuctionVehicle;"

Write-Host "`nResult summary:"
Invoke-Sqlcmd `
    -ServerInstance $SqlInstance `
    -Database $Database `
    -Query $checkSql `
    -TrustServerCertificate |
    Format-Table -AutoSize