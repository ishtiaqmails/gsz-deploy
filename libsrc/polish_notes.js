'use strict';
/* Premium wording polish for the remaining product notes — same meaning, clean phrasing.
   Keyed by slug so each change is explicit and reviewable; reversible from admin. */
const ROOT = '/opt/gsz';
require(ROOT + '/node_modules/dotenv').config({ path: ROOT + '/.env' });
const { Pool } = require(ROOT + '/node_modules/pg');
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

const MAP = {
  'surfshark-vpn': 'Signs in with a one-time code (OTP)',
  'mysterium-vpn': 'Signs in via a magic link',
  'capcut': 'Please don’t share the login — sharing can get the account blocked, which isn’t covered by warranty',
  'picsart': 'AI credits not included',
  'udemy-premium': 'Certificates not included',
  'hot-player': 'Media player only — no channels or IPTV subscription included',
  'ibo-player': 'Media player only — no channels or IPTV subscription included'
};

(async () => {
  let changed = 0;
  for (const slug of Object.keys(MAP)) {
    const row = (await pool.query('SELECT id, name, note FROM products WHERE slug=$1', [slug])).rows[0];
    if (!row) { console.log('  (not found: ' + slug + ')'); continue; }
    if ((row.note || '') === MAP[slug]) continue;
    console.log('  ' + row.name + ': "' + (row.note || '') + '"  ->  "' + MAP[slug] + '"');
    await pool.query('UPDATE products SET note=$1 WHERE id=$2', [MAP[slug], row.id]);
    changed++;
  }
  console.log(changed ? ('polished ' + changed + ' note(s)') : 'already polished');
  console.log('--- final notes on the site ---');
  const kept = (await pool.query("SELECT name, note FROM products WHERE note IS NOT NULL AND note <> '' ORDER BY id")).rows;
  kept.forEach(k => console.log('  ' + k.name + ': "' + k.note + '"'));
  await pool.end();
  console.log('POLISH OK');
})().catch(e => { console.error('FAIL ' + e.message); process.exit(1); });
