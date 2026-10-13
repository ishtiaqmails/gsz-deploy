'use strict';
/* Make every product note premium + non-redundant:
   - strip a leading device/profile/login count (e.g. "1 Device Login - OTP Code" -> "OTP Code",
     "1 Device Login through Magic Link" -> "Magic Link"), since the plan label already shows it;
   - drop notes that only echo the plan label (e.g. "25 Downloads/Day");
   - keep genuine must-know caveats untouched ("No channels included", "AI credits not included",
     "Certifications not included", sharing warnings, OTP/magic-link login hints).
   Prints every change + the final set. Reversible from admin. */
const ROOT = '/opt/gsz';
require(ROOT + '/node_modules/dotenv').config({ path: ROOT + '/.env' });
const { Pool } = require(ROOT + '/node_modules/pg');
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

const PREFIX = /^\s*\d+\s*(?:device|devices|profile|profiles)\s*(?:login|logins|account|accounts)?\s*(?:[-–—:|]|through|via)?\s*/i;
const ECHO = /^\s*\d+\s*downloads?\s*\/?\s*(?:a\s*)?(?:day|daily)?\s*$/i; // "25 Downloads/Day" — already in the plan label

(async () => {
  const rows = (await pool.query("SELECT id, name, note FROM products WHERE note IS NOT NULL AND note <> ''")).rows;
  let changed = 0;
  for (const r of rows) {
    let next = r.note.replace(PREFIX, '').trim();
    if (next === '' || ECHO.test(next)) next = null;
    if (next === r.note) continue;
    console.log('  ' + r.name + ': "' + r.note + '"  ->  ' + (next === null ? '(removed)' : '"' + next + '"'));
    await pool.query('UPDATE products SET note=$1 WHERE id=$2', [next, r.id]);
    changed++;
  }
  console.log(changed ? ('updated ' + changed + ' note(s)') : 'nothing to change');
  console.log('--- final notes on the site ---');
  const kept = (await pool.query("SELECT name, note FROM products WHERE note IS NOT NULL AND note <> '' ORDER BY id")).rows;
  kept.forEach(k => console.log('  ' + k.name + ': "' + k.note + '"'));
  await pool.end();
  console.log('CLEANNOTES3 OK');
})().catch(e => { console.error('FAIL ' + e.message); process.exit(1); });
