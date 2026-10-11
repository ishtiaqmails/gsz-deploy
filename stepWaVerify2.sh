#!/usr/bin/env bash
# Galaxy — WhatsApp verification fixes:
#  • simple 6-digit numeric code (no more GX-ABCDEF)
#  • bot verifies on "VERIFY <code>", a bare code, OR legacy GX- code
#  • verified accounts stop being asked (webhook now sets customers.wa_verified; + backfill)
#  • verify screen shows the destination number with a copy button
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
WR=routes/whatsapp.js
HM=views/partials/hub_model.ejs
cp -f "$WR" "$WR.bak.$TS"
cp -f "$HM" "$HM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$WR.bak.$TS" "$WR"; cp -f "$HM.bak.$TS" "$HM"; }
trap restore ERR

node "$SRC/patch_waverify.js" "$GSZ"
node --check "$WR"

cp -f "$SRC/hub_model.ejs" "$HM"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$HM','utf8'),{filename:process.cwd()+'/'+'$HM'});console.log('  hub_model ejs ok');"

# backfill: anyone already linked in the WhatsApp system but whose flag was never set
BF="UPDATE customers SET wa_verified=true WHERE wa_verified=false AND id IN (SELECT customer_id FROM customer_whatsapp_links WHERE status='ACTIVE' AND is_primary=true);"
( sudo -u postgres psql -d gsz -c "$BF" 2>&1 || psql -U gsz_user -d gsz -c "$BF" 2>&1 ) | tail -1

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — numeric codes, code-only verify, verified-flag sync + backfill, and the number is now shown on the verify screen."
