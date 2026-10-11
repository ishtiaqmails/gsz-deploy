#!/usr/bin/env bash
# GSZ — Admin WhatsApp: add a NUMBERS manager to /admin/whatsapp. Edit the verification,
# owner, support and sales/website numbers anytime; saved to wa_settings, which every part
# of the system reads live — so a change applies everywhere at once (verification link,
# support redirects, notifications, store contact, admin reset code). Nothing hardcoded.
# Refreshes routes/adminWhatsapp.js + views/admin/whatsapp.ejs (router/nav already mounted).
# Idempotent; backs up; auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-wanums-$TS"
cd "$GSZ"
FILES=(routes/adminWhatsapp.js views/admin/whatsapp.ejs)
echo "==> backup -> $BK"
mkdir -p "$BK"; for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

cp -f "$SRC/adminWhatsapp.js" "$GSZ/routes/adminWhatsapp.js"
cp -f "$SRC/adm_whatsapp.ejs" "$GSZ/views/admin/whatsapp.ejs"

echo "==> validate"
node --check "$GSZ/routes/adminWhatsapp.js"
node -e "const ejs=require('$GSZ/node_modules/ejs');ejs.compile(require('fs').readFileSync('$GSZ/views/admin/whatsapp.ejs','utf8'),{filename:'$GSZ/views/admin/whatsapp.ejs'});console.log('    whatsapp ejs ok')"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — WhatsApp numbers manager live on /admin/whatsapp (edit anytime, applies everywhere)."
