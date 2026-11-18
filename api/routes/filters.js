/*
  routes/filters.js

  GET /api/filters
    Returns all filter options in one call so the front end
    can populate every dropdown and slider on page load
    without making three separate requests.

    Response:
      {
        makes: [
          { Make: "CHEVROLET", VehicleCount: 12, EarliestYear: 2008, LatestYear: 2022 },
          ...
        ],
        yearRange: { MinYear: 2004, MaxYear: 2022, TotalVehicles: 70 },
        bodyClasses: [
          { BodyClass: "Sport Utility Vehicle (SUV)", VehicleCount: 24 },
          ...
        ]
      }
*/

'use strict';

const express = require('express');
const router  = express.Router();
const { getPool } = require('../db');

router.get('/', async (req, res) => {
    try {
        const pool = await getPool();

        // Three result sets in one round trip
        const result = await pool.request().query(
            'SELECT Make, VehicleCount, EarliestYear, LatestYear ' +
            'FROM pub.vw_MakeList ' +
            'ORDER BY VehicleCount DESC; ' +

            'SELECT MinYear, MaxYear, TotalVehicles ' +
            'FROM pub.vw_YearRange; ' +

            'SELECT BodyClass, VehicleCount ' +
            'FROM pub.vw_BodyClassList ' +
            'ORDER BY VehicleCount DESC;'
        );

        res.json({
            makes:       result.recordsets[0],
            yearRange:   result.recordsets[1][0],
            bodyClasses: result.recordsets[2]
        });

    } catch (err) {
        console.error('GET /api/filters error:', err);
        res.status(500).json({ error: 'Database error' });
    }
});

module.exports = router;
