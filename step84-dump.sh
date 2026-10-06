#!/usr/bin/env bash
# step84-dump — READ-ONLY. Shows the orders schema and how checkout creates an
# order, so I can link orders to the logged-in customer cleanly. Changes nothing.
set -euo pipefail
APP=/opt/gsz
cd "$APP"

echo "========== orders table columns =========="
node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{
  const cols = (await p.query("SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_name='orders' ORDER BY ordinal_position")).rows;
  if(!cols.length){ console.log('(no orders table found)'); }
  cols.forEach(c=>console.log('  '+c.column_name+'  '+c.data_type+(c.is_nullable==='NO'?' NOT NULL':'')+(c.column_default?('  default '+c.column_default):'')));
  const n = (await p.query("SELECT count(*)::int n FROM orders").catch(()=>({rows:[{n:'?'}]}))).rows[0].n;
  console.log('  -- rows: '+n);
  // order_items table?
  const oi = (await p.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name='order_items' ORDER BY ordinal_position")).rows;
  if(oi.length){ console.log('========== order_items columns =========='); oi.forEach(c=>console.log('  '+c.column_name+'  '+c.data_type)); }
  await p.end();
})().catch(e=>{ console.error(e.message); p.end(); });
NODE

echo
echo "========== checkout.js: INSERT INTO orders (with context) =========="
grep -nE "INSERT INTO orders|order_items|req\.session|customer" "$APP/routes/checkout.js" || echo "(no matches)"
echo
echo "---- full INSERT blocks ----"
grep -n -A3 "INSERT INTO orders" "$APP/routes/checkout.js" || true

echo
echo "========== how orders are read (track / order route) =========="
grep -nE "FROM orders|SELECT .* orders|router\.(get|post)" "$APP/routes/checkout.js" | head -40
echo "---- pages/track route files ----"
ls -1 "$APP/routes" | grep -iE "track|order" || true

echo
echo "==> step84-dump done (read-only)"
