/*
  routes/vehicles.js
  GET /api/vehicles            - paginated vehicle list (pub.usp_GetVehicles)
                                 ?make ?yearMin ?yearMax ?bodyClass
                                 ?featured=true|false ?page ?pageSize
  GET /api/vehicles/car-image  - proxy to Pixabay image search (must be before /:id)
  GET /api/vehicles/:id        - single vehicle by VehicleId
*/

'use strict';

const express = require('express');
const router  = express.Router();
const { getPool, sql } = require('../db');

// ------------------------------------------------------------------
// GET /api/vehicles
// ------------------------------------------------------------------
router.get('/', async (req, res) => {
    try {
        const pool = await getPool();
        const page     = Math.max(1, parseInt(req.query.page)     || 1);
        const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize) || 20));
        const request  = pool.request();

        // Filters are optional; anything not supplied is passed as NULL
        // and the stored procedure ignores it.
        const yearMin = parseInt(req.query.yearMin);
        const yearMax = parseInt(req.query.yearMax);
        const featured = req.query.featured;   // ?featured=true | false

        request.input('Make',       sql.NVarChar(100), req.query.make      || null);
        request.input('YearMin',    sql.SmallInt,      Number.isNaN(yearMin) ? null : yearMin);
        request.input('YearMax',    sql.SmallInt,      Number.isNaN(yearMax) ? null : yearMax);
        request.input('BodyClass',  sql.NVarChar(100), req.query.bodyClass || null);
        request.input('IsFeatured', sql.Bit,
            featured === 'true' || featured === '1'  ? 1 :
            featured === 'false' || featured === '0' ? 0 : null);
        request.input('Page',       sql.Int, page);
        request.input('PageSize',   sql.Int, pageSize);

        // Returns: [0] page of vehicles, [1] TotalCount
        const result     = await request.execute('pub.usp_GetVehicles');
        const vehicles   = result.recordsets[0];
        const totalCount = result.recordsets[1][0].TotalCount;

        res.json({
            data:       vehicles,
            page,
            pageSize,
            totalCount,
            totalPages: Math.ceil(totalCount / pageSize)
        });
    } catch (err) {
        console.error('GET /api/vehicles error:', err);
        res.status(500).json({ error: 'Database error' });
    }
});

// ------------------------------------------------------------------
// GET /api/vehicles/car-image?make=CHEVROLET&model=Traverse&year=2009
// NOTE: must be defined before /:id or Express treats "car-image" as an id
// ------------------------------------------------------------------
router.get('/car-image', async (req, res) => {
    const { make, model, year } = req.query;
    if (!make || !model) return res.status(400).json({ error: 'make and model required' });
    try {
        // Build a search query like "2009 Chevrolet Traverse car"
        const searchQ = [year, make, model, 'car'].filter(Boolean).join(' ');
        const params = new URLSearchParams({
            key:          process.env.PIXABAY_API_KEY,
            q:            searchQ,
            image_type:   'photo',
            category:     'transportation',
            per_page:     3,
            safesearch:   true
        });
        const response = await fetch('https://pixabay.com/api/?' + params);
        const data = await response.json();
        const imgUrl = data && data.hits && data.hits[0]
            ? data.hits[0].webformatURL
            : null;
        res.json({ url: imgUrl });
    } catch (err) {
        console.error('car-image error:', err);
        res.json({ url: null });
    }
});

// ------------------------------------------------------------------
// GET /api/vehicles/:id
// ------------------------------------------------------------------
router.get('/:id', async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        if (isNaN(id)) return res.status(400).json({ error: 'Invalid vehicle ID' });

        const pool    = await getPool();
        const request = pool.request();
        request.input('id', sql.Int, id);

        const result = await request.query(
            'SELECT VehicleId, Make, Model, ModelYear, Color, ' +
            '       BodyClass, Vin, SaleDate, IsVerified, IsFeatured ' +
            'FROM pub.vw_Vehicle WHERE VehicleId = @id;'
        );

        if (result.recordset.length === 0) return res.status(404).json({ error: 'Vehicle not found' });
        res.json(result.recordset[0]);
    } catch (err) {
        console.error('GET /api/vehicles/:id error:', err);
        res.status(500).json({ error: 'Database error' });
    }
});

module.exports = router;