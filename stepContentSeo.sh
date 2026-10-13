#!/usr/bin/env bash
# stepContentSeo.sh — guides/articles always get a meta description (body-derived fallback) +
# unique per-hub list descriptions. In-place, idempotent; restores on failure.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/routes/content.js.bak-seo-$TS"; cd "$GSZ"
cp routes/content.js "$BK"; echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK" "$GSZ/routes/content.js"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR
node "$SRC/patch_contentseo.js"
node --check "$GSZ/routes/content.js" && echo "   content.js ok"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "   --- guide head check ---"
curl -s http://127.0.0.1:3900/buying-guides/how-to-get-free-iptv-trial | grep -oE '<meta name="description"[^>]*>' | head -1
echo "DONE — guides/articles always have a meta description"
