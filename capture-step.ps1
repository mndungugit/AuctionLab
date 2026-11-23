# capture-step.ps1
# Snaps a full-screen screenshot and commits it to the AuctionLab repo.
# Run this whenever you reach a milestone you want to preserve.
#
# Usage:
#   .\capture-step.ps1               # prompts for step + label
#   .\capture-step.ps1 -Step 9 -Label "vin-images-working"

param(
    [string]$Step,
    [string]$Label
)

# ── Repo root ──────────────────────────────────────────────────────────────
$RepoRoot      = "C:\AuctionLab"
$ScreenshotsDir = "$RepoRoot\screenshots"

# ── Prompt if not supplied ─────────────────────────────────────────────────
if (-not $Step)  { $Step  = Read-Host "Step number  (e.g. 09)" }
if (-not $Label) { $Label = Read-Host "Short label  (e.g. vin-images-working)" }

# Normalise: lowercase, spaces → hyphens, strip unsafe chars
$SafeLabel = $Label.ToLower() -replace '[^a-z0-9]+', '-'
$SafeLabel = $SafeLabel.Trim('-')

$StepPadded = $Step.PadLeft(2, '0')
$Timestamp  = Get-Date -Format "yyyy-MM-dd"
$Filename   = "step-$StepPadded-$Timestamp-$SafeLabel.png"
$OutputPath = "$ScreenshotsDir\$Filename"

# ── Ensure screenshots/ folder exists ──────────────────────────────────────
New-Item -ItemType Directory -Force -Path $ScreenshotsDir | Out-Null

# ── Capture primary display ────────────────────────────────────────────────
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$screen   = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bitmap   = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

Write-Host ""
Write-Host "Screenshot saved → $Filename" -ForegroundColor Green

# ── Git: stage + commit ────────────────────────────────────────────────────
Push-Location $RepoRoot

$RelPath = "screenshots/$Filename"
git add $RelPath

$CommitMsg = "screenshot: step $StepPadded - $SafeLabel"
git commit -m $CommitMsg

Pop-Location

Write-Host "Committed:  $CommitMsg" -ForegroundColor Cyan
Write-Host "Run  git push  when you're ready to push to GitHub." -ForegroundColor DarkGray
