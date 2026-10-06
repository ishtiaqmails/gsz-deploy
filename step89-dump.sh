#!/usr/bin/env bash
# step89-dump — READ-ONLY. Shows how IPTV servers / trial plans are modeled and
# what the bot API exposes, so I can design the trial system. Changes nothing.
set -euo pipefail
APP=/opt/gsz
cd "$APP"

echo "========== product_plans columns =========="
node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{
  const cols = (await p.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name='product_plans' ORDER BY ordinal_position")).rows;
  cols.forEach(c=>console.log('  '+c.column_name+'  '+c.data_type));
  console.log('========== product_plans sample (bot-mapped / IPTV) ==========');
  const rows = (await p.query("SELECT product_id, label, source, bot_sku, bot_plan_key, bot_type, price_pkr FROM product_plans WHERE source='bot' OR bot_sku IS NOT NULL ORDER BY product_id, sort, id LIMIT 40")).rows;
  rows.forEach(r=>console.log('  pid='+r.product_id+' | '+r.label+' | src='+r.source+' sku='+r.bot_sku+' plan='+r.bot_plan_key+' type='+r.bot_type+' price='+r.price_pkr));
  console.log('========== plans that look like TRIALS (price 0 / "trial") ==========');
  const tr = (await p.query("SELECT product_id, label, bot_sku, bot_plan_key, bot_type, price_pkr FROM product_plans WHERE price_pkr=0 OR lower(label) LIKE '%trial%' OR lower(coalesce(bot_plan_key,'')) LIKE '%trial%' ORDER BY product_id LIMIT 40")).rows;
  if(!tr.length) console.log('  (none found by that heuristic)');
  tr.forEach(r=>console.log('  pid='+r.product_id+' | '+r.label+' | sku='+r.bot_sku+' plan='+r.bot_plan_key+' type='+r.bot_type+' price='+r.price_pkr));
  // bot_products table?
  const bp = (await p.query("SELECT column_name FROM information_schema.columns WHERE table_name='bot_products' ORDER BY ordinal_position")).rows;
  if(bp.length){ console.log('========== bot_products columns =========='); console.log('  '+bp.map(c=>c.column_name).join(', '));
    const s = (await p.query("SELECT sku, name, delivery_type FROM bot_products WHERE lower(coalesce(delivery_type,'')) LIKE '%iptv%' OR lower(coalesce(delivery_type,'')) IN ('stock','activation_api') ORDER BY sku LIMIT 30").catch(()=>({rows:[]}))).rows;
    console.log('  -- IPTV-ish bot_products (up to 30):'); s.forEach(r=>console.log('    '+r.sku+' | '+r.name+' | '+r.delivery_type));
  } else { console.log('========== bot_products: (no such table) =========='); }
  await p.end();
})().catch(e=>{ console.error('diag error:', e.message); p.end(); });
NODE

echo
echo "========== botapi.js: exported methods + endpoints it calls =========="
grep -nE "function |req\('(GET|POST)'|module.exports" lib/botapi.js | head -60

echo
echo "========== any existing 'trial' references in routes/lib =========="
grep -rniE "trial" routes lib --include=*.js | grep -viE "node_modules" | head -30 || echo "(none)"

echo
echo "==> step89-dump done (read-only)"
