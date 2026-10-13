'use strict';
/* Clean 'old warranty' duplication from product NOTE fields. Warranty belongs only to the
   admin Product Model's warranty field (shown in the green Warranty box). Some notes still
   lead with a duplicated warranty phrase (e.g. "28 Days Validity Warranty - 1 Device Login");
   this strips that leading phrase, keeping the genuinely useful remainder ("1 Device Login").
   Surgical: only notes that LEAD with a warranty phrase are touched; everything else is left
   exactly as-is. Prints every change. Reversible from admin. */
const ROOT = '/opt/gsz';
require(ROOT + '/node_modules/dotenv').config({ path: ROOT + '/.env' });
const { Pool } = require(ROOT + '/node_modules/pg');
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

// leading "<n> day(s)/month(s)/year(s) [validity] warranty [sep]"
const RE = /^\s*\d+\s*(?:day|days|month|months|year|years)\s*(?:validity\s*)?warranty\s*(?:[-–—:|]\s*)?/i;

(async () => {
  const rows = (await pool.query("SELECT id, name, note FROM products WHERE note IS NOT NULL AND note <> ''")).rows;
  let changed = 0;
  for (const r of rows) {
    if (!RE.test(r.note)) continue;
    const next = r.note.replace(RE, '').trim();
    console.log('  ' + r.name + ':');
    console.log('    was: "' + r.note + '"');
    console.log('    now: "' + next + '"');
    await pool.query('UPDATE products SET note=$1 WHERE id=$2', [next || null, r.id]);
    changed++;
  }
  console.log(changed ? ('cleaned ' + changed + ' note(s) — warranty now shows only from the Product Model warranty field') : 'no notes needed cleaning');
  await pool.end();
  console.log('CLEANNOTES OK');
})().catch(e => { console.error('FAIL ' + e.message); process.exit(1); });
