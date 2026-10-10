#!/usr/bin/env bash
# Repurpose the hamburger drawer: swap duplicated category links for real site pages.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
mapfile -t HDR < <(grep -rlF 'id="drawerCats"' views --include='*.ejs' | grep -v '\.bak')
[ ${#HDR[@]} -gt 0 ] || { echo "!! drawer file not found (id=drawerCats)"; exit 1; }
for f in "${HDR[@]}"; do cp -f "$f" "$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in "${HDR[@]}"; do cp -f "$f.bak.$TS" "$f"; done; }
trap restore ERR

node "$SRC/patch_drawer.js" "$GSZ"
for f in "${HDR[@]}"; do
  node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$f','utf8'),{filename:process.cwd()+'/$f'});console.log('  ejs ok: $f');"
done
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — hamburger repurposed: Track · Resellers · About · FAQ · WhatsApp Channel (categories now live on the Store tab)."
