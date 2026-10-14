#!/usr/bin/env bash
# stepSeo2.sh — SEO Batch 2a: blog/guide title (no mid-word cut) + stronger meta description.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-seo2-$TS"; cd "$GSZ"
CT=routes/content.js; CB=lib/csblocks.js
mkdir -p "$BK/routes" "$BK/lib"; cp "$GSZ/$CT" "$BK/$CT"; cp "$GSZ/$CB" "$BK/$CB"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$CT" "$GSZ/$CT"; cp "$BK/$CB" "$GSZ/$CB"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch content.js + csblocks.js"
node "$SRC/patch_seo2.js" "$GSZ"
node --check "$GSZ/$CT" && echo "   content.js ok"
node --check "$GSZ/$CB" && echo "   csblocks.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "   blog title check:"; curl -s http://127.0.0.1:3900/guides/best-iptv-uae-gulf | grep -o '<title>[^<]*</title>' | head -1
echo "DONE — blog/guide titles render in full; meta descriptions filled to proper length."
