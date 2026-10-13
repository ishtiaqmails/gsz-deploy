'use strict';
/* Remove product notes that only restate what the plan label already shows (device/login count).
   The plan pill already says e.g. "1 Device - 1 Profile", so a note "1 Device Login" is pure
   clutter on a premium page. Only notes that are ENTIRELY this redundancy are removed; notes
   with a real caveat (OTP code, magic link, "no channels included", "AI credits not included",
   download limits, etc.) are kept exactly as-is. Prints every change; reversible from admin. */
const ROOT = '/opt/gsz';
require(ROOT + '/node_modules/dotenv').config({ path: ROOT + '/.env' });
const { Pool } = require(ROOT + '/node_modules/pg');
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

// a note that is ONLY "<n> device [login/account]" or "<n> profile [login]" — redundant with the plan label
const REDUNDANT = /^\s*\d+\s*(?:device|devices|profile|profiles)\s*(?:login|logins|account|accounts)?\s*$/i;

(async () => {
  const rows = (await pool.query("SELECT id, name, note FROM products WHERE note IS NOT NULL AND note <> ''")).rows;
  let removed = 0;
  for (const r of rows) {
    if (!REDUNDANT.test(r.note)) continue;
    console.log('  ' + r.name + ': removed redundant note "' + r.note + '" (plan label already shows this)');
    await pool.query('UPDATE products SET note=NULL WHERE id=$1', [r.id]);
    removed++;
  }
  console.log(removed ? ('removed ' + removed + ' redundant note(s)') : 'no redundant notes found');
  console.log('--- notes kept (genuine caveats) ---');
  const kept = (await pool.query("SELECT name, note FROM products WHERE note IS NOT NULL AND note <> '' ORDER BY id")).rows;
  kept.forEach(k => console.log('  ' + k.name + ': "' + k.note + '"'));
  await pool.end();
  console.log('CLEANNOTES2 OK');
})().catch(e => { console.error('FAIL ' + e.message); process.exit(1); });
