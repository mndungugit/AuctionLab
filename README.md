# AuctionLab

A full-stack web app I built to browse real vehicle auction inventory from a local towing company in Marietta, GA. The vehicles come from KO Towing's Title 40-11-2 impound auctions — these are actual cars that have been towed and go up for public bid under Georgia state law.

The idea started simple: I wanted a better way to browse what's available before auction day. It turned into a full project with a live database, a REST API, and a custom-built frontend with real-time filtering.

---

## What It Does

- **Browse 70+ live vehicles** pulled directly from a SQL Server database
- **Filter by make, year range, and body type** — results update instantly
- **Manager's Special** featured on the homepage — always shows the newest vehicle in inventory
- **Vehicle detail pages** with full specs and VIN lookup
- **VIN-based vehicle images** served from a live image source
- **Responsive dark UI** built from scratch — no component libraries

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 18, Vite, React Router |
| Backend | Node.js, Express |
| Database | SQL Server (T-SQL stored procedures) |
| Styling | Custom CSS with design tokens |
| Images | VIN-based S3 image source |
| Dev tools | PowerShell automation, Git |

---

## Project Structure

```
AuctionLab/
├── client/               # React + Vite frontend
│   └── src/
│       ├── api/          # API client, image fetching
│       ├── components/   # VehicleCard
│       └── pages/        # BrowsePage, DetailPage
├── api/                  # Express REST API
│   └── server.js         # Endpoints: /api/vehicles, /api/filters
└── screenshots/          # Progress screenshots committed over time
```

---

## Running It Locally

You'll need Node.js and access to a SQL Server instance with the auction data.

**1. Start the API**
```bash
cd api
npm install
node server.js
# API runs on http://localhost:3001
```

**2. Start the frontend**
```bash
cd client
npm install
npm run dev
# App runs on http://localhost:3000
```

The API connects to SQL Server using environment variables — connection details are kept out of source control.

---

## API Endpoints

```
GET /api/vehicles              # Paginated vehicle list
GET /api/vehicles/:id          # Single vehicle detail
GET /api/filters               # Available makes, body types, year range
```

Supports query params: `make`, `yearMin`, `yearMax`, `bodyClass`, `page`, `pageSize`

---

## Background

This is a personal side project.  I spend most of my professional time deep in T-SQL, stored procedures, and query optimization — this project was a chance to flex that backend muscle while also pushing myself on the full-stack side.

The data pipeline starts with auction files from the towing company, gets loaded into SQL Server, and surfaces through a Node API to the React frontend. The whole thing runs on real data, not mock data.

---

## Screenshots

Progress screenshots are committed to the `screenshots/` folder — you can see the UI evolve from the original layout to the current dark redesign.

---

## What's Next

- Auction date countdown timers per vehicle
- Email/SMS alert when a specific make hits the inventory
- Admin panel to manage featured vehicles
- Deploy to a public URL

---

*Built by Marvin Ndungu · Atlanta, GA*
