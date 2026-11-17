# =============================================================
#  config.example.ps1  –  AuctionLab configuration template
#
#  HOW TO USE
#  ----------
#  1. Copy this file:  Copy-Item config.example.ps1 config.ps1
#  2. Open config.ps1 and fill in every value marked <...>.
#  3. config.ps1 is listed in .gitignore and will never be
#     committed to the repo.  This template file IS committed
#     so anyone cloning the repo knows what values are needed.
#
#  Every script in the scripts\ folder starts with:
#       . "$PSScriptRoot\..\config.ps1"
#  which loads these variables before doing any work.
# =============================================================

# SQL Server instance name shown in the SSMS connect dialog.
# Examples: 'localhost'  |  'localhost\SQLEXPRESS'  |  '.\SQLEXPRESS'
$SqlInstance  = '<YOUR_SQL_SERVER_INSTANCE>'

# Database (leave as AuctionLab unless you renamed it)
$Database     = 'AuctionLab'

# Full path to pdftotext.exe from the Poppler for Windows package.
# Download: https://github.com/oschwartz10612/poppler-windows/releases
# Example:  'C:\Tools\poppler\Library\bin\pdftotext.exe'
$PdfToTextExe = '<FULL_PATH_TO_pdftotext.exe>'

# Local working root.  The scripts create downloads\ and logs\
# under this folder automatically on first run.
$WorkingRoot  = 'C:\AuctionLab'
$DownloadDir  = "$WorkingRoot\downloads"
$LogDir       = "$WorkingRoot\logs"

# Public URL of the auction PDF.  Change only if K.O. Towing
# moves it to a different address.
$AuctionUrl   = 'https://www.kotowing.net/pdf/auction-list-marietta.pdf'
$WebReaderPassword = '@webReader123'  # Password for the auctionlab_web SQL Server login