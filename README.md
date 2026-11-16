# AuctionLab

A local data pipeline that downloads the K.O. Towing auction vehicle list,
parses it into SQL Server, validates VINs against the NHTSA database, and
powers a browsable inventory site.

Built as a learning project covering T-SQL, PowerShell, a REST API, and a
React front end.

---

## Repo layout

```
AuctionLab/
├── .gitignore
├── README.md
├── config.example.ps1          ← copy to config.ps1 and fill in your values
│
├── sql/
│   ├── 01_create_auctionlab.sql    ← database, schemas, and staging tables
│   ├── 02_parse_auction_batch.sql  ← stored proc: raw lines → vehicle rows
│   ├── 03_vin_functions.sql        ← check-digit function + VinDecode table
│   └── ...                         ← analysis views, pub schema, web_reader
│
└── scripts/
    ├── 02_load_auction_pdf.ps1     ← download PDF, hash-check, load raw lines
    ├── 03_decode_vins.ps1          ← call NHTSA API, verify VINs
    └── ...                         ← scheduling helpers
```

Scripts are numbered to match the build steps so you can follow the work
in order on GitHub.

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| SQL Server 2022 or later (Developer or Express) | Database |
| SQL Server Management Studio (SSMS) | Run SQL scripts |
| PowerShell 5.1 or later | Ingest and decode scripts |
| [Poppler for Windows](https://github.com/oschwartz10612/poppler-windows/releases) | `pdftotext.exe` extracts text from the PDF |
| SqlServer PowerShell module | Insert rows from PowerShell |

Install the PowerShell module once:
```powershell
Install-Module -Name SqlServer -Scope CurrentUser -Force
```

---

## First-time setup

**Step 1 – Clone the repo and set up your config**

```powershell
git clone https://github.com/<your-username>/AuctionLab.git
cd AuctionLab
Copy-Item config.example.ps1 config.ps1
# Open config.ps1 in VS Code and fill in your SQL instance name,
# path to pdftotext.exe, and working folder.
```

**Step 2 – Create the local working folders**

```powershell
. .\config.ps1          # load $DownloadDir and $LogDir
New-Item -ItemType Directory -Force $WorkingRoot, $DownloadDir, $LogDir
```

**Step 3 – Run the SQL setup script**

Open SSMS, connect to your instance, open `sql\01_create_auctionlab.sql`,
and run it.  The script is rerunnable — it skips anything already created.

**Step 4 – Run the ingest script**

```powershell
.\scripts\02_load_auction_pdf.ps1
```

Expect about 75 raw lines on the first run.  On re-runs with no new file
uploaded, the script prints "No new file – same hash as last run" and exits.

---

## Security

`config.ps1` is git-ignored. It holds your SQL Server instance name,
local file paths, and (later) the `web_reader` database password.
**Never commit it.**  `config.example.ps1` is the safe template that
shows what values are needed without containing any real values.

Do not commit screenshots taken in SSMS — they can contain your machine
name and Windows user name.

---

## Build progress

| Step | What it builds | Status |
|------|---------------|--------|
| 1 | Database, schemas, staging tables (`01_create_auctionlab.sql`) | ✅ Done |
| 2 | Repo layout, .gitignore, config template | ✅ Done |
| 3 | Download PDF + load raw lines (`02_load_auction_pdf.ps1`) | 🔜 Next |
| 4 | Parse raw lines → vehicle rows (T-SQL stored proc) | ⬜ |
| 5 | VIN validation + NHTSA decode | ⬜ |
| 6 | Analysis views and bid sheet | ⬜ |
| 7 | Inventory + pub schema + web_reader login | ⬜ |
| 8 | ASP.NET Core Web API | ⬜ |
| 9 | React front end | ⬜ |
| 10 | Scheduling + hosting | ⬜ |
