#!/usr/bin/env bash
set -uo pipefail
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
PID=$(pm2 pid gsz 2>/dev/null | head -1 | tr -dc '0-9')
if [ -n "${PID:-}" ] && [ -r "/proc/$PID/environ" ]; then
  while IFS= read -r -d '' kv; do export "$kv" 2>/dev/null || true; done < "/proc/$PID/environ"
  echo "loaded env from gsz pid $PID"
else
  echo "could not read gsz process env (pid='${PID:-}')"
fi
cat > .gszm_diag.js <<'JS'
const fs = require('fs');
const { Pool } = require('pg');
function cfgFromSource() {
  const files = ['server.js', 'app.js', 'index.js', 'db.js', 'lib/db.js', 'lib/pool.js', 'lib/pg.js', 'lib/database.js'];
  for (const f of files) {
    try {
      const src = fs.readFileSync(f, 'utf8');
      const m = src.match(/new\s+Pool\s*\(([\s\S]*?)\)/);
      if (m) { const inner = m[1].trim(); return { cfg: inner ? eval('(' + inner + ')') : {}, from: f }; }
    } catch (e) {}
  }
  return null;
}
(async () => {
  let pool = null, how = '';
  try {
    pool = new Pool(process.env.DATABASE_URL ? { connectionString: process.env.DATABASE_URL } : {});
    await pool.query('SELECT 1'); how = 'env';
  } catch (e) {
    try { if (pool && pool.end) await pool.end(); } catch (x) {}
    const s = cfgFromSource();
    if (s) { try { pool = new Pool(s.cfg); await pool.query('SELECT 1'); how = 'source:' + s.from; } catch (e2) { console.log('source connect err:', e2.message); pool = null; } }
    else { console.log('no Pool config found in source'); }
  }
  if (!pool) { console.log('COULD NOT CONNECT'); process.exit(0); }
  console.log('pool via:', how);
  try {
    const cols = await pool.query("SELECT column_name FROM information_schema.columns WHERE table_name='payment_logos'");
    console.log('columns:', cols.rows.map(r => r.column_name).join(', '));
    const rows = await pool.query('SELECT key, extra_label, extra_value FROM payment_logos ORDER BY key');
    console.log('rows:', JSON.stringify(rows.rows));
  } catch (e) { console.log('DB ERR:', e.message); }
  try { await pool.end(); } catch (e) {}
  process.exit(0);
})();
JS
node .gszm_diag.js
rm -f .gszm_diag.js
