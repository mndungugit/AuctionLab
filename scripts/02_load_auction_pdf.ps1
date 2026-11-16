# =============================================================
#  02_load_auction_pdf.ps1
#
#  Purpose : Download the auction PDF, hash-check it, extract
#            the text lines, and load them into SQL Server.
#  Rerun   : Safe. If the same file has already been loaded,
#            the script prints "No new file" and exits cleanly.
#  Requires: config.ps1 in the parent folder (one level up),
#            pdftotext.exe (Poppler), SqlServer PS module.
#
#  Contains no server names, passwords, or file paths.
#  All values come from config.ps1 (git-ignored).
# =============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------
# 1. Load config
# ------------------------------------------------------------------
$configPath = Join-Path $PSScriptRoot '..\config.ps1'
if (-not (Test-Path $configPath)) {
    Write-Error "config.ps1 not found. Copy config.example.ps1 to config.ps1 and fill in your values."
    exit 1
}
. $configPath

# ------------------------------------------------------------------
# 2. Make sure working folders exist
# ------------------------------------------------------------------
foreach ($dir in $DownloadDir, $LogDir) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-Host "Created folder: $dir"
    }
}

# ------------------------------------------------------------------
# 3. Set up logging
# ------------------------------------------------------------------
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile   = Join-Path $LogDir "load_$timestamp.log"
$pdfFile   = Join-Path $DownloadDir 'auction-list-marietta.pdf'
$txtFile   = Join-Path $DownloadDir 'auction-list-marietta.txt'

function Write-Log {
    param([string]$msg)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-Log '=== 02_load_auction_pdf.ps1 started ==='

# ------------------------------------------------------------------
# 4. Download the PDF
# ------------------------------------------------------------------
Write-Log "Downloading: $AuctionUrl"
try {
    Invoke-WebRequest -Uri $AuctionUrl -OutFile $pdfFile -UseBasicParsing
    Write-Log "Download complete."
}
catch {
    Write-Log "ERROR downloading PDF: $_"
    exit 1
}

# ------------------------------------------------------------------
# 5. Hash the file
# ------------------------------------------------------------------
$hash = (Get-FileHash -Path $pdfFile -Algorithm SHA256).Hash.ToUpper()
Write-Log "SHA-256: $hash"

# ------------------------------------------------------------------
# 6. Check if already loaded
# ------------------------------------------------------------------
$checkSql = "SELECT COUNT(1) FROM dbo.AuctionBatch WHERE SourceUrl = '$AuctionUrl' AND FileHash = '$hash';"

$alreadyLoaded = Invoke-Sqlcmd `
    -ServerInstance $SqlInstance `
    -Database $Database `
    -Query $checkSql `
    -TrustServerCertificate |
    Select-Object -ExpandProperty Column1

if ($alreadyLoaded -gt 0) {
    Write-Log 'No new file - same hash already loaded. Nothing to do.'
    Write-Log '=== Script finished (no-op) ==='
    exit 0
}

Write-Log 'New file detected. Proceeding with load.'

# ------------------------------------------------------------------
# 7. Extract text from PDF
# ------------------------------------------------------------------
Write-Log 'Running pdftotext...'
& $PdfToTextExe '-layout' '-nopgbrk' $pdfFile $txtFile

if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: pdftotext exited with code $LASTEXITCODE"
    exit 1
}
Write-Log "Text extracted: $txtFile"

# ------------------------------------------------------------------
# 8. Read lines
# ------------------------------------------------------------------
$lines        = Get-Content -Path $txtFile -Encoding UTF8
$rawLineCount = $lines.Count
Write-Log "Lines read: $rawLineCount"

# ------------------------------------------------------------------
# 9. Insert AuctionBatch row
# ------------------------------------------------------------------
$insertBatchSql = "INSERT INTO dbo.AuctionBatch (SourceUrl, FileHash, RawLineCount, BatchStatus) " +
                  "VALUES ('$AuctionUrl', '$hash', $rawLineCount, 'Downloading'); " +
                  "SELECT SCOPE_IDENTITY() AS BatchId;"

$batchId = [int](Invoke-Sqlcmd `
    -ServerInstance $SqlInstance `
    -Database $Database `
    -Query $insertBatchSql `
    -TrustServerCertificate |
    Select-Object -ExpandProperty BatchId)

Write-Log "AuctionBatch row created. BatchId = $batchId"

# ------------------------------------------------------------------
# 10. Load lines into stg.AuctionListRaw
# ------------------------------------------------------------------
Write-Log "Loading $rawLineCount lines into stg.AuctionListRaw..."

$lineNumber = 0
foreach ($line in $lines) {
    $lineNumber++
    $safeText      = $line -replace "'", "''"
    $insertLineSql = "INSERT INTO stg.AuctionListRaw (BatchId, LineNumber, RawText) " +
                     "VALUES ($batchId, $lineNumber, N'$safeText');"
    Invoke-Sqlcmd `
        -ServerInstance $SqlInstance `
        -Database $Database `
        -Query $insertLineSql `
        -TrustServerCertificate | Out-Null
}

Write-Log 'All lines inserted.'

# ------------------------------------------------------------------
# 11. Mark batch as Loaded
# ------------------------------------------------------------------
$updateSql = "UPDATE dbo.AuctionBatch SET BatchStatus = 'Loaded', RawLineCount = $rawLineCount WHERE BatchId = $batchId;"

Invoke-Sqlcmd `
    -ServerInstance $SqlInstance `
    -Database $Database `
    -Query $updateSql `
    -TrustServerCertificate | Out-Null

Write-Log 'BatchStatus updated to Loaded.'
Write-Log "=== Script finished. BatchId = $batchId, Lines = $rawLineCount ==="