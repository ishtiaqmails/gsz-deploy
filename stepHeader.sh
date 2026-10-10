#!/usr/bin/env bash
# Mobile header fix: fit logo + IPTV Free Trial + WhatsApp + menu on one row (source edit in app.css).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"

CSS="$(find . -type f -name 'app.css' -path '*css*' 2>/dev/null | grep -v '\.bak' | head -1)"
[ -n "$CSS" ] || { echo "!! app.css not found"; exit 1; }
HEAD="$(grep -rl 'app.css?v=' views --include='*.ejs' 2>/dev/null | grep -v '\.bak' | head -1)"
[ -n "$HEAD" ] || { echo "!! head partial referencing app.css?v= not found"; exit 1; }
echo "  css:  $CSS"
echo "  head: $HEAD"

cp -f "$CSS" "$CSS.bak.$TS"; cp -f "$HEAD" "$HEAD.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$CSS.bak.$TS" "$CSS"; cp -f "$HEAD.bak.$TS" "$HEAD"; }
trap restore ERR

node "$SRC/patch_hdr.js" "$CSS"

# bump the app.css cache-busting ?v= so browsers fetch the new stylesheet
cur="$(grep -oE 'app\.css\?v=[0-9]+' "$HEAD" | head -1 | grep -oE '[0-9]+$' || true)"
if [ -n "$cur" ]; then
  new=$((cur+1)); sed -i "s#app\.css?v=${cur}#app.css?v=${new}#g" "$HEAD"; echo "  cache-bust: app.css v${cur} -> v${new}"
else
  echo "  (no numeric ?v= found to bump — leaving as-is)"
fi
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — mobile header now one tidy row (logo left · trial + WhatsApp + menu right · search below). Keep trial: yes."
