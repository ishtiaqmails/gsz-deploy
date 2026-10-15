#!/usr/bin/env bash
# stepIptVer.sh — IPTV version label (Family Account / Full Account) in the delivery message,
# clean credentials mirrored to the admin order page, and warranty fallback to the bot's own.
# Patches lib/deliveryMsg.js (composer) + routes/checkout.js + lib/deliver.js. Idempotent; restores on failure.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-iptver-$TS"; cd "$GSZ"
CO=routes/checkout.js; DV=lib/deliver.js; DM=lib/deliveryMsg.js
mkdir -p "$BK/routes" "$BK/lib"
cp "$GSZ/$CO" "$BK/$CO"; cp "$GSZ/$DV" "$BK/$DV"; cp "$GSZ/$DM" "$BK/$DM"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$CO" "$GSZ/$CO"; cp "$BK/$DV" "$GSZ/$DV"; cp "$BK/$DM" "$GSZ/$DM"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> deploy composer + patch delivery blocks"
cp -f "$SRC/deliveryMsg.js" "$GSZ/$DM"
node --check "$GSZ/$DM" && echo "   deliveryMsg.js ok"
node "$SRC/patch_iptver.js" "$GSZ"
node --check "$GSZ/$CO" && echo "   checkout.js ok"
node --check "$GSZ/$DV" && echo "   deliver.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "   health OK (${i}s)"; break; }; sleep 1; done

echo "==> backfill GSZ-2012 admin credentials (no customer message)"
node - "$GSZ" <<'NODE' || echo "   (backfill skipped — non-fatal)"
const R=process.argv[2];
require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const {Pool}=require(R+'/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
const botapi=require(R+'/lib/botapi'); const deliveryMsg=require(R+'/lib/deliveryMsg');
(async()=>{
  const o=(await pool.query("SELECT * FROM orders WHERE order_no='GSZ-2012'")).rows[0];
  if(!o||o.source!=='bot'){ console.log('   no bot order'); await pool.end(); return; }
  const st=await botapi.orderStatus(o.order_no); const f=st&&st.fields;
  if(!f||!f.delivery_type){ console.log('   no structured fields'); await pool.end(); return; }
  const plw=(await pool.query("SELECT warranty,bot_sku,version_labels FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort,id LIMIT 1",[o.product_id,o.plan_label])).rows[0]||{};
  let vlabel=''; const vk=String(o.bot_type||'').trim();
  if(vk){ const btl=(await pool.query("SELECT label FROM bot_type_labels WHERE sku=$1 AND type_key=$2 LIMIT 1",[plw.bot_sku,vk])).rows[0];
    if(btl&&btl.label) vlabel=btl.label; else { let vls=plw.version_labels; if(typeof vls==='string'){try{vls=JSON.parse(vls);}catch(e){vls=null;}} if(Array.isArray(vls)){const mm=vls.find(v=>v&&v.key===vk); if(mm&&mm.label) vlabel=mm.label;} } }
  const warr=((plw.warranty||'').trim())||((f&&f.warranty)||'');
  const m=deliveryMsg.compose(o,f,{siteName:'Galaxy Subz × Zayron',warranty:warr,versionLabel:vlabel});
  if(m.credentials){ await pool.query("UPDATE orders SET delivered_credentials=$1 WHERE id=$2",[m.credentials,o.id]); console.log('   GSZ-2012 credentials updated -> version "'+vlabel+'"'); }
  else console.log('   nothing to update');
  await pool.end();
})().catch(e=>{console.error('   backfill err',e.message);process.exit(0);});
NODE

echo "DONE — IPTV version label now shows in delivery (e.g. '1 Month — Family Account'), admin shows the clean credentials, warranty falls back to the bot's when unset."
