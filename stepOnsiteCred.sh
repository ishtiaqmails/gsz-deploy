#!/usr/bin/env bash
# stepOnsiteCred.sh — premium on-site credentials card in the hub (My Subscriptions).
#   1) orders.bot_fields (jsonb) — cache for the structured delivery fields
#   2) routes/orderFields.js — GET /account/tools/order-fields/:no (lazy capture, owner-checked)
#   3) mount it; deploy hub_model.ejs (renders the premium card; raw text stays as fallback)
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-onsite-$TS"; cd "$GSZ"
SV=server.js; HM=views/partials/hub_model.ejs; RT=routes/orderFields.js
mkdir -p "$BK/views/partials" "$BK/routes"
cp "$GSZ/$SV" "$BK/$SV"; cp "$GSZ/$HM" "$BK/$HM"; [ -f "$GSZ/$RT" ] && cp "$GSZ/$RT" "$BK/$RT" || true
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$SV" "$GSZ/$SV"; cp "$BK/$HM" "$GSZ/$HM"; [ -f "$BK/$RT" ] && cp "$BK/$RT" "$GSZ/$RT" || rm -f "$GSZ/$RT"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> 1) migrate orders.bot_fields"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ await p.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS bot_fields jsonb'); console.log('   bot_fields ready'); await p.end(); })().catch(e=>{console.error(e.message);process.exit(1);});
"

echo "==> 2/3) deploy endpoint + hub, mount"
cp -f "$SRC/orderFields.js" "$GSZ/$RT"
cp -f "$SRC/hub_model.ejs" "$GSZ/$HM"
node "$SRC/orderFields_mount.js"

echo "==> checks"
node --check "$GSZ/$RT" && echo "   orderFields.js ok"
node --check "$GSZ/$SV" && echo "   server.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/$HM','utf8'),{filename:'$GSZ/$HM'});console.log('   hub_model.ejs ok');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — My Subscriptions now shows the premium credentials card (per type), raw text as fallback"
