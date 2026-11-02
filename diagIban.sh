#!/usr/bin/env bash
set -uo pipefail
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
cat > .gszm_diag.js <<'JS'
(async () => {
  let pool = null, how = '';
  const cands = ['./db', './lib/db', './lib/pool', './config/db', './lib/pg', './models/db'];
  for (const m of cands) {
    try { const x = require(m); const p = (x && x.query) ? x : (x && x.pool) ? x.pool : (x && x.default) ? x.default : null; if (p && p.query) { pool = p; how = 'module ' + m; break; } } catch (e) {}
  }
  if (!pool) { try { require('dotenv').config(); } catch (e) {} const { Pool } = require('pg'); pool = new Pool(process.env.DATABASE_URL ? { connectionString: process.env.DATABASE_URL } : {}); how = 'env Pool'; }
  console.log('pool via:', how);
  try {
    const cols = await pool.query("SELECT column_name FROM information_schema.columns WHERE table_name='payment_logos'");
    console.log('columns:', cols.rows.map(r => r.column_name).join(', '));
    const rows = await pool.query('SELECT key, extra_label, extra_value FROM payment_logos ORDER BY key');
    console.log('rows:', JSON.stringify(rows.rows));
  } catch (e) { console.log('DB ERR:', e.message); }
  try {
    const bot = require('./lib/botapi');
    if (bot && bot.configured && bot.configured()) {
      const accts = await bot.getPayAccounts();
      console.log('bot keys:', (accts || []).map(a => String(a.key)).join(', '));
    } else { console.log('bot not configured'); }
  } catch (e) { console.log('BOT ERR:', e.message); }
  try { if (pool.end) await pool.end(); } catch (e) {}
  process.exit(0);
})();
JS
node .gszm_diag.js
rm -f .gszm_diag.js
