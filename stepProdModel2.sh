#!/usr/bin/env bash
# GSZ admin — Product Model editor: (1) shorter & categorical — Basics / Description /
# Plans / Capabilities / FAQs / Downloads are all collapsible sections (tap to expand;
# only Basics open by default). (2) "Auto-fill plans from bot product": pick the bot IPTV
# product + set your own version labels once -> it generates all paid-duration plans
# pre-mapped (price, bot plan, versions); trials skipped. Only the view changes.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-prodmodel2-$TS"; cd "$GSZ"
F=views/admin/product_model.ejs
mkdir -p "$BK/$(dirname "$F")"; cp "$GSZ/$F" "$BK/$F"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$F" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
cp -f "$SRC/adm_product_model.ejs" "$GSZ/$F"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const p='$GSZ/$F';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   product_model ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Product editor is now collapsible/categorical, with Auto-fill plans from bot (+ your own version labels)."
