#!/usr/bin/env bash
# dumpIptvProvision.sh — read-only. Does a paid IPTV order actually ask the bot to CREATE a line?
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$1"; }

echo "### A) deliver.js — how a bot/IPTV order is fulfilled (provisioning calls) ###"
grep -nE "submitOrder|bot_order_id|provision|createLine|fulfill|iptv|activat|retrieveOtp|credsource|getStock|deliveryType|delivery_type|source *=== *'bot'|botapi\." "$GSZ/lib/deliver.js" 2>/dev/null | head -40

echo
echo "### B) botapi.js — the create-line / submit-order surface ###"
grep -nE "function submitOrder|function orderStatus|function verifyClaim|/api/(submit|order|create|provision|line)|activat" "$GSZ/lib/botapi.js" 2>/dev/null | head -15

echo
echo "### C) credsource / iptv worker — where IPTV credentials come from ###"
grep -nE "submitOrder|generate-trial|generateTrial|stock|create|line|retrieve|source|FREE-TRIAL|order-status" "$GSZ/lib/iptv/credsource.js" 2>/dev/null | head -20

echo
echo "### D) LIVE: recent StarShare (SKU-00101) orders — did they get a bot_order_id? ###"
node - "$GSZ" <<'NODE' 2>&1 | head -30
const R=process.argv[2]; try{require(R+'/node_modules/dotenv').config({path:R+'/.env'});}catch(e){}
const {Pool}=require(R+'/node_modules/pg');const E=process.env;
let pool=E.DATABASE_URL?new Pool({connectionString:E.DATABASE_URL}):((E.DB_HOST||E.DB_NAME)?new Pool({host:E.DB_HOST||'127.0.0.1',port:+(E.DB_PORT||5432),user:E.DB_USER||E.PGUSER,password:(E.DB_PASS||E.DB_PASSWORD||E.PGPASSWORD||'')+'',database:E.DB_NAME||E.PGDATABASE}):new Pool());
(async()=>{ try{
  const r=await pool.query("SELECT id,order_no,status,bot_sku,bot_type,bot_order_id,source,LEFT(COALESCE(delivered_credentials,''),60) cred,created_at FROM orders WHERE bot_sku='SKU-00101' OR product_name ILIKE '%starshare%' ORDER BY id DESC LIMIT 6");
  if(!r.rows.length) console.log('  no StarShare orders found');
  r.rows.forEach(o=>console.log('  #'+o.id+' '+(o.order_no||'')+' status='+o.status+' sku='+o.bot_sku+' type='+(o.bot_type||'-')+' bot_order_id='+(o.bot_order_id||'(none)')+' src='+o.source+'\n      cred: '+(o.cred||'(empty)')));
  const bp=await pool.query("SELECT sku,LEFT(name,20) nm,delivery_type FROM bot_products WHERE sku='SKU-00101' OR name ILIKE '%starshare%'");
  bp.rows.forEach(x=>console.log('  bot_products: '+x.sku+' '+x.nm+' delivery_type='+x.delivery_type));
  const pl=await pool.query("SELECT pr.name, pp.source, pp.bot_sku, pp.bot_plan_key FROM product_plans pp JOIN products pr ON pr.id=pp.product_id WHERE pp.bot_sku='SKU-00101' OR pr.name ILIKE '%starshare%' LIMIT 4");
  pl.rows.forEach(x=>console.log('  plan: '+x.name+' source='+x.source+' bot_sku='+x.bot_sku+' plan_key='+(x.bot_plan_key||'-')));
}catch(e){console.log('  db err:',e.message);} try{await pool.end();}catch(e){} })();
NODE
echo "== END =="
