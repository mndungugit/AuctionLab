/*
  db.js
  Singleton connection pool to SQL Server.
  All routes call getPool() — the connection is created once
  and reused for the life of the process.

  Credentials come from .env (git-ignored), never hardcoded.
*/

'use strict';

const sql = require('mssql');

const config = {
    server:   process.env.DB_SERVER,
    database: process.env.DB_DATABASE,
    user:     process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    options: {
        trustServerCertificate: true,   // required for local SQL Server
        encrypt: false
    },
    pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
    }
};

let pool = null;

async function getPool() {
    if (!pool) {
        pool = await sql.connect(config);
        console.log('SQL Server pool connected.');
    }
    return pool;
}

module.exports = { getPool, sql };
