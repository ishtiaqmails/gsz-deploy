'use strict';
/* migrate.js — safe additive migration runner. Connects exactly like server.js (DB_HOST/DB_PORT/
   DB_NAME/DB_USER/DB_PASS from /opt/gsz/.env), runs a .sql file inside ONE transaction (all-or-
   nothing), rolls back on any error, then verifies. Never touches existing tables (the SQL is
   CREATE TABLE IF NOT EXISTS only). Usage: node migrate.js <file.sql> */
const path = require('path');
const GSZ = process.env.GSZ_DIR || '/opt/gsz';
require(path.join(GSZ, 'node_modules', 'dotenv')).config({ path: path.join(GSZ, '.env') });
const { Pool } = require(path.join(GSZ, 'node_modules', 'pg'));
const fs = require('fs');

const sqlFile = process.argv[2];
if (!sqlFile) { console.error('usage: node migrate.js <file.sql>'); process.exit(1); }

const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASS
});

(async () => {
  const sql = fs.readFileSync(sqlFile, 'utf8');
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    await c.query(sql);
    await c.query('COMMIT');
    console.log('migration committed OK: ' + path.basename(sqlFile));
  } catch (e) {
    try { await c.query('ROLLBACK'); } catch (_) {}
    console.error('MIGRATION FAILED (rolled back, nothing changed): ' + e.message);
    c.release(); await pool.end(); process.exit(1);
  }
  try {
    const r = await c.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name LIKE 'geo\\_%' OR table_name LIKE 'seo\\_%') ORDER BY table_name");
    console.log('geo/seo tables present (' + r.rows.length + '): ' + r.rows.map(x => x.table_name).join(', '));
    const gi = await c.query('SELECT count(*)::int n FROM geo_intents');
    console.log('geo_intents seeded: ' + gi.rows[0].n);
  } catch (e) { console.error('verify note: ' + e.message); }
  c.release(); await pool.end();
})().catch(e => { console.error('ERR ' + e.message); process.exit(1); });
