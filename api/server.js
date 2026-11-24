/*
  server.js
  AuctionLab Web API entry point.

  Endpoints
    GET /api/vehicles          paginated vehicle list with optional filters
    GET /api/vehicles/:id      single vehicle detail
    GET /api/filters           all filter options (makes, year range, body classes)
    GET  /api/admin/vehicles                all vehicles + featured status   (admin key)
    POST /api/admin/vehicles/:id/featured   toggle featured for one vehicle  (admin key)
    GET /health                liveness check

  Credentials come from .env (git-ignored), never hardcoded.
*/

'use strict';

require('dotenv').config();

const express  = require('express');
const cors     = require('cors');

const vehiclesRouter = require('./routes/vehicles');
const filtersRouter  = require('./routes/filters');
const adminRouter    = require('./routes/admin');

const app  = express();
const PORT = process.env.PORT || 3001;

// ------------------------------------------------------------------
// Middleware
// ------------------------------------------------------------------
app.use(cors());          // allow React dev server (port 3000) to call us
app.use(express.json());

// ------------------------------------------------------------------
// Routes
// ------------------------------------------------------------------
app.use('/api/vehicles', vehiclesRouter);
app.use('/api/filters',  filtersRouter);
app.use('/api/admin',    adminRouter);     // requires X-Admin-Key header

// Liveness check — handy for testing that the server is up
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 404 fallback
app.use((req, res) => {
    res.status(404).json({ error: 'Not found' });
});

// ------------------------------------------------------------------
// Start
// ------------------------------------------------------------------
app.listen(PORT, () => {
    console.log(`AuctionLab API listening on http://localhost:${PORT}`);
    console.log('Endpoints:');
    console.log(`  GET http://localhost:${PORT}/health`);
    console.log(`  GET http://localhost:${PORT}/api/filters`);
    console.log(`  GET http://localhost:${PORT}/api/vehicles`);
    console.log(`  GET http://localhost:${PORT}/api/vehicles/:id`);
    console.log(`  GET http://localhost:${PORT}/api/admin/vehicles` +
        (process.env.ADMIN_API_KEY ? '' : '   (disabled: ADMIN_API_KEY not set)'));
});
