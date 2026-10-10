#!/usr/bin/env bash
# Repurpose the JS-built hamburger drawer to pages (edits app.js buildDrawerCats + cache-busts app.js).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"

JS="$(find . -type f -name 'app.js' -path '*js*' | grep -v '\.bak' | head -1)"
HEAD="$(grep -rl 'app.js?v=' views --include='*.ejs' | grep -v '\.bak' | head -1)"
[ -n "$JS" ]   || { echo "!! app.js not found"; exit 1; }
[ -n "$HEAD" ] || { echo "!! no view references app.js?v="; exit 1; }
echo "  js:$JS  head:$HEAD"

cp -f "$JS" "$JS.bak.$TS"; cp -f "$HEAD" "$HEAD.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$JS.bak.$TS" "$JS"; cp -f "$HEAD.bak.$TS" "$HEAD"; }
trap restore ERR

node "$SRC/patch_appjs.js" "$JS"
node --check "$JS"

cur="$(grep -oE 'app\.js\?v=[0-9]+' "$HEAD" | head -1 | grep -oE '[0-9]+$' || true)"
if [ -n "$cur" ]; then new=$((cur+1)); sed -i "s#app\.js?v=${cur}#app.js?v=${new}#g" "$HEAD"; echo "  cache-bust: app.js v${cur} -> v${new}"; fi
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — hamburger now shows pages (Track · Resellers · About · FAQ · Channel · My Account)."
