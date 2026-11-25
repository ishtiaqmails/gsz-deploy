#!/usr/bin/env bash
# diagRenewReminders — the renewal-reminder code on BOTH sites + how an IPTV product is identified, so we
# can restrict reminders to IPTV only. READ-ONLY.
set +e
echo "################## galaxyzayron (/opt/gsz) ##################"
cd /opt/gsz 2>/dev/null && {
  echo "### reminder timer + query (checkout.js) ###"
  grep -n "renew_remind\|remTimer\|renewable\|reminder\|renew_reminded" routes/checkout.js | head -20
  echo "--- context 1095-1160 ---"
  sed -n '1095,1160p' routes/checkout.js
  echo "### how IPTV is identified (products / bot_products delivery_type) ###"
  node - <<'NODE'
const {Pool}=require("pg");const fs=require("fs");
const env={};try{fs.readFileSync(".env","utf8").split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/);if(m)env[m[1]]=m[2].replace(/^["']|["']$/g,"").trim();});}catch(e){}
const p=new Pool({host:env.DB_HOST||"127.0.0.1",port:+(env.DB_PORT||5432),user:env.DB_USER,password:env.DB_PASS||env.DB_PASSWORD,database:env.DB_NAME});
(async()=>{try{
  const pc=(await p.query("SELECT column_name FROM information_schema.columns WHERE table_name='products' ORDER BY ordinal_position")).rows.map(x=>x.column_name);
  console.log("products cols:", pc.join(", "));
  const bc=(await p.query("SELECT column_name FROM information_schema.columns WHERE table_name='bot_products' ORDER BY ordinal_position")).rows.map(x=>x.column_name);
  console.log("bot_products cols:", bc.join(", "));
  const dts=(await p.query("SELECT DISTINCT delivery_type FROM bot_products ORDER BY 1")).rows.map(x=>x.delivery_type);
  console.log("bot_products delivery_types:", dts.join(", "));
  const sample=(await p.query("SELECT id,name,renewable, (SELECT delivery_type FROM bot_products bp JOIN product_plans pp ON pp.bot_sku=bp.sku WHERE pp.product_id=products.id LIMIT 1) AS dt FROM products ORDER BY id LIMIT 12")).rows;
  console.log("product sample (id,name,renewable,delivery_type):"); sample.forEach(r=>console.log("  ",JSON.stringify(r)));
}catch(e){console.log("db err:",e.message)}process.exit(0)})();
NODE
}
echo
echo "################## zayron.tv (/opt/zayron) ##################"
cd /opt/zayron 2>/dev/null && {
  echo "### any renewal reminder code? ###"
  grep -rln "renew.*remind\|reminder\|renew_reminded\|expires.*remind\|renewal" --include=*.js routes lib *.js 2>/dev/null | grep -v node_modules | grep -v "\.bak" | head
  grep -rn "renew_remind\|reminder\|renew_reminded" --include=*.js routes lib *.js 2>/dev/null | grep -v node_modules | grep -v "\.bak" | head -20
}
echo DONE
