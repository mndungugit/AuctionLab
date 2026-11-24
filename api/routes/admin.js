/*
  routes/admin.js
  Admin endpoints for managing featured vehicles.

  GET  /api/admin/vehicles                - all vehicles with IsFeatured
  POST /api/admin/vehicles/:id/featured   - toggle IsFeatured for one vehicle

  Every request must send the admin key in an X-Admin-Key header,
  matching ADMIN_API_KEY in .env. If ADMIN_API_KEY is not set, the
  admin API is disabled (503).
*/

'use strict';

const crypto  = require('crypto');
const express = require('express');
const router  = express.Router();
const { getPool, sql } = require('../db');


// ------------------------------------------------------------------
// Auth: shared admin key
// ------------------------------------------------------------------
function requireAdminKey(req, res, next) {
    const expected = process.env.ADMIN_API_KEY;
    if (!expected) {
        return res.status(503).json({ error: 'Admin API is disabled (ADMIN_API_KEY not set)' });
    }

    const supplied = req.get('X-Admin-Key') || '';
    const a = Buffer.from(supplied);
    const b = Buffer.from(expected);
    if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();

   
}

router.use(requireAdminKey);

// ------------------------------------------------------------------
// GET /api/admin/vehicles
// All vehicles (no paging) with their featured status.
// Featured vehicles first, then by VehicleId.
// ------------------------------------------------------------------
router.get('/vehicles', async (req, res) => {
    try {
        const pool   = await getPool();
        const result = await pool.request().query(
            'SELECT VehicleId, Make, Model, ModelYear, Color, ' +
            '       BodyClass, Vin, SaleDate, IsVerified, IsFeatured ' +
            'FROM pub.vw_Vehicle ' +
            'ORDER BY IsFeatured DESC, VehicleId;'
        );
        const vehicles = result.recordset;

        res.json({
            data:          vehicles,
            totalCount:    vehicles.length,
            featuredCount: vehicles.filter(v => v.IsFeatured).length
        });
    } catch (err) {
        console.error('GET /api/admin/vehicles error:', err);
        res.status(500).json({ error: 'Database error' });
    }
});

// ------------------------------------------------------------------
// POST /api/admin/vehicles/:id/featured
// Toggles IsFeatured. Responds with the new value.
// ------------------------------------------------------------------
router.post('/vehicles/:id/featured', async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) {
        return res.status(400).json({ error: 'Invalid vehicle ID' });
    }

    try {
        const pool   = await getPool();
        const result = await pool.request()
            .input('VehicleId', sql.Int, id)
            .execute('admin.usp_ToggleVehicleFeatured');

        const row = result.recordset[0];
        if (!row) return res.status(404).json({ error: 'Vehicle not found' });

        res.json({ VehicleId: row.VehicleId, IsFeatured: row.IsFeatured });
    } catch (err) {
        console.error(`POST /api/admin/vehicles/${id}/featured error:`, err);
        res.status(500).json({ error: 'Database error' });
    }
});

module.exports = router;
