#!/usr/bin/env bash
# GSZ — Admin: WhatsApp Connection section (premium mobile + desktop model).
# Live control panel for the verification bot (gszwabot) — status card (connected
# number + uptime), Reconnect, Log out & re-pair, and a live QR panel. Reads the bot's
# secret-gated /status, /reconnect, /logout over localhost; QR rendered to an image here.
#   NEW:     routes/adminWhatsapp.js, views/admin/whatsapp.ejs
#   PATCHED: server.js (mount), views/admin/_shell_top.ejs (nav)
#   DEP:     qrcode (installed if missing)
# Idempotent; backs up, validates, auto-restores on failure. Does NOT touch the bot
# or the reseller bot.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-wa-admin-$TS"; TMP=$(mktemp -d)
cd "$GSZ"

PATCHED=(server.js views/admin/_shell_top.ejs)
NEW=(routes/adminWhatsapp.js views/admin/whatsapp.ejs)

echo "==> backup -> $BK"
mkdir -p "$BK"
for f in "${PATCHED[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
NEWHAD=()
for f in "${NEW[@]}"; do if [ -f "$GSZ/$f" ]; then NEWHAD+=("$f"); mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; fi; done
restore(){
  echo "!! FAILED — restoring"
  for f in "${PATCHED[@]}"; do cp "$BK/$f" "$GSZ/$f"; done
  for f in "${NEW[@]}"; do keep=0; for h in "${NEWHAD[@]:-}"; do [ "$h" = "$f" ] && keep=1; done
    if [ "$keep" = "1" ]; then cp "$BK/$f" "$GSZ/$f"; else rm -f "$GSZ/$f"; fi; done
  pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."
}
trap 'restore' ERR

echo "==> copy new files"
cp -f "$SRC/adminWhatsapp.js" "$GSZ/routes/adminWhatsapp.js"
cp -f "$SRC/adm_whatsapp.ejs" "$GSZ/views/admin/whatsapp.ejs"

echo "==> ensure qrcode dependency"
if node -e "require.resolve('qrcode')" >/dev/null 2>&1; then echo "   qrcode present"
else echo "   installing qrcode…"; ( cd "$GSZ" && npm i qrcode --no-audit --no-fund >/dev/null 2>&1 ) && echo "   qrcode installed" || echo "   !! qrcode install failed — page still works, QR shows as text-less placeholder"; fi

echo "==> apply patches"
cp -f "$SRC/patch_whatsapp_admin.js" "$TMP/p.js"
node "$TMP/p.js" "$GSZ"

echo "==> validate"
node --check "$GSZ/routes/adminWhatsapp.js"
node --check "$GSZ/server.js"
node -e "const ejs=require('$GSZ/node_modules/ejs');['views/admin/whatsapp.ejs','views/admin/_shell_top.ejs'].forEach(function(f){ejs.compile(require('fs').readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});console.log('    ejs ok '+f)})"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
rm -rf "$TMP"
echo "DONE — Admin → WhatsApp Connection live (/admin/whatsapp), both models."
