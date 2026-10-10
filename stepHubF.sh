#!/usr/bin/env bash
# Galaxy Hub — Deploy F (UI polish): remove Support+My Orders tiles, Free Trial chooser + My Trials
# (tap-to-reveal), in-model Sign in/Create Account, 6-tile Quick Access grid, tablet/header breakpoints.
# Partials (inline) + one app.css header media query. No DB change.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
CT=views/partials/customer_tools.ejs
NAV=views/partials/app_nav.ejs
CSS="$(find public -type f -name app.css | grep -v '\.bak' | head -1)"
HCSS="$(grep -rl 'app\.css?v=' views --include='*.ejs' | grep -v '\.bak' | head -1)"
mapfile -t FOOTERS < <(grep -rlF '<footer class="ft">' views --include='*.ejs' | grep -v '\.bak')
[ -n "$CSS" ] || { echo "!! app.css not found"; exit 1; }
echo "  css:$CSS  hcss:$HCSS"

cp -f "$CT" "$CT.bak.$TS"; cp -f "$NAV" "$NAV.bak.$TS"; cp -f "$CSS" "$CSS.bak.$TS"
[ -n "$HCSS" ] && cp -f "$HCSS" "$HCSS.bak.$TS"
for f in "${FOOTERS[@]}"; do cp -f "$f" "$f.bak.$TS"; done
restore(){ echo "!! failed — restoring"; cp -f "$CT.bak.$TS" "$CT"; cp -f "$NAV.bak.$TS" "$NAV"; cp -f "$CSS.bak.$TS" "$CSS"; [ -n "$HCSS" ] && cp -f "$HCSS.bak.$TS" "$HCSS"; for f in "${FOOTERS[@]}"; do cp -f "$f.bak.$TS" "$f"; done; }
trap restore ERR

cp -f "$SRC/customer_tools.ejs" "$CT"
cp -f "$SRC/app_nav.ejs" "$NAV"
node "$SRC/patch_appnav.js" "$GSZ"
node "$SRC/patch_hdrbp.js" "$CSS"

# cache-bust app.css (static)
if [ -n "$HCSS" ]; then cur="$(grep -oE 'app\.css\?v=[0-9]+' "$HCSS" | head -1 | grep -oE '[0-9]+$' || true)"; [ -n "$cur" ] && { new=$((cur+1)); sed -i "s#app\.css?v=${cur}#app.css?v=${new}#g" "$HCSS"; echo "  bust app.css v${cur}->v${new}"; }; fi

node -e "const ejs=require('ejs'),fs=require('fs');['$CT','$NAV'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  hub ejs ok');"
for f in "${FOOTERS[@]}"; do node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$f','utf8'),{filename:process.cwd()+'/$f'});"; done; echo "  footers ejs ok"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy F: Support/My Orders removed · Free Trial chooser + My Trials · in-model auth · 6-tile Quick Access · tablet/header breakpoints."
