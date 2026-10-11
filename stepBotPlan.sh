#!/usr/bin/env bash
# Galaxy — Add Product / Edit Product model: Reseller Bot mapping now has a Bot-plan
# selector, so an IPTV (multi-plan) bot product can map each site plan to the exact
# bot duration (bot_plan_key). Copies the rebuilt partial into views/. Auto-restores on error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
DST=views/admin/product_model.ejs
cp -f "$DST" "$DST.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$DST.bak.$TS" "$DST"; }
trap restore ERR
cp -f "$SRC/adm_product_model.ejs" "$DST"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$DST','utf8'),{filename:process.cwd()+'/'+'$DST'});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Bot-plan selector live. For an IPTV bot product, pick the bot plan (duration) under the Reseller Bot mapping on each site plan."
