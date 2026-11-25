#!/usr/bin/env bash
# diagDeliveryMsg — full delivery-message composer (warranty + expiry rendering) and how warranty is sourced,
# so IPTV shows expiry (no warranty) and non-IPTV shows the reseller-bot warranty. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ lib/deliveryMsg.js (FULL) ############"
nl -ba lib/deliveryMsg.js
echo
echo "############ where warranty is sourced before compose (deliver.js + checkout.js) ############"
grep -n "warranty\|_warr\|\.expiry\|fields.expiry\|delivery_type\|warranty_days" lib/deliver.js routes/checkout.js | head -40
echo
echo "############ bot_products warranty_days sample (reseller-bot dashboard warranty) ############"
node - <<'NODE'
const {Pool}=require("pg");const fs=require("fs");
const env={};try{fs.readFileSync(".env","utf8").split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/);if(m)env[m[1]]=m[2].replace(/^["']|["']$/g,"").trim();});}catch(e){}
const p=new Pool({host:env.DB_HOST||"127.0.0.1",port:+(env.DB_PORT||5432),user:env.DB_USER,password:env.DB_PASS||env.DB_PASSWORD,database:env.DB_NAME});
(async()=>{try{
  const r=(await p.query("SELECT sku,name,delivery_type,warranty_days FROM bot_products WHERE warranty_days IS NOT NULL ORDER BY delivery_type, sku LIMIT 20")).rows;
  r.forEach(x=>console.log("  ",JSON.stringify(x)));
  const iptv=(await p.query("SELECT sku,name,warranty_days FROM bot_products WHERE delivery_type='iptv' ORDER BY sku LIMIT 8")).rows;
  console.log("IPTV bot_products (note warranty_days):"); iptv.forEach(x=>console.log("  ",JSON.stringify(x)));
}catch(e){console.log("db err:",e.message)}process.exit(0)})();
NODE
echo DONE
