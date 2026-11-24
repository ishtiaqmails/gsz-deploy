#!/usr/bin/env bash
# diagGszDeliver5 — confirm the renew-recovery gap: order #43 fields/flags, any other stuck orders, and
# the checkout renew path (does it persist fields.renew_of/renew_line so the drainer polls renewStatus?). READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ order #43 fields + renew flags + any OTHER stuck 'delivering' ############"
node - <<'NODE'
const {Pool}=require("pg");const fs=require("fs");
const env={};try{fs.readFileSync(".env","utf8").split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/);if(m)env[m[1]]=m[2].replace(/^["']|["']$/g,"").trim();});}catch(e){}
const p=new Pool({host:env.DB_HOST||"127.0.0.1",port:+(env.DB_PORT||5432),user:env.DB_USER,password:env.DB_PASS||env.DB_PASSWORD,database:env.DB_NAME});
(async()=>{try{
  const o=(await p.query("SELECT id,order_no,status,claim_result,bot_order_id,bot_sku,source,plan_label,product_name,fields FROM orders WHERE id=43")).rows[0]||{};
  console.log("order43:",JSON.stringify({id:o.id,order_no:o.order_no,status:o.status,claim_result:o.claim_result,bot_order_id:o.bot_order_id,bot_sku:o.bot_sku,source:o.source}));
  let f=o.fields; if(typeof f==='string'){try{f=JSON.parse(f);}catch(e){}}
  console.log("order43.fields:", f?JSON.stringify(f).slice(0,500):"(null)");
  console.log("has renew_of/renew_line?:", !!(f&&(f.renew_of||f.renew_line)));
  const stuck=(await p.query("SELECT id,order_no,status,claim_result,bot_order_id,product_name,plan_label,created_at FROM orders WHERE status='delivering' ORDER BY id DESC")).rows;
  console.log("STUCK delivering now:", stuck.length);
  stuck.forEach(s=>console.log("  ",JSON.stringify(s)));
  // is bot_products delivery_type for this sku one of hotplayer/ibosol/zayron?
  try{ const dt=(await p.query("SELECT sku,delivery_type FROM bot_products WHERE sku=$1",[o.bot_sku])).rows[0]; console.log("bot_product:",JSON.stringify(dt)); }catch(e){console.log("bot_products err:",e.message)}
}catch(e){console.log("db err:",e.message)}process.exit(0)})();
NODE
echo
echo "############ checkout.js renew/activate/submit flow (345-465) ############"
sed -n '345,465p' routes/checkout.js
echo
echo "############ checkout.js drainer (604-630) ############"
sed -n '604,632p' routes/checkout.js
echo DONE
