#!/usr/bin/env bash
# GSZ — Notify-me is now a bell ON each out-of-stock plan (not a separate box).
# Patches views/product.ejs (adds the pill bell + delegated waitlist handler, hides the
# old restock box). Backs up, validates (ejs compile), restarts, restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-notifybell-$TS"; cd "$GSZ"
F=views/product.ejs
mkdir -p "$BK/$(dirname "$F")"; cp "$GSZ/$F" "$BK/$F"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$F" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_notifybell.js" "$GSZ"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const p='$GSZ/$F';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   product.ejs ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Notify-me is now a bell on each out-of-stock plan; the separate box is hidden."
