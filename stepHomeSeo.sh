#!/usr/bin/env bash
# stepHomeSeo.sh — homepage title + full SEO (meta description, canonical, Open Graph/Twitter,
# Organization + WebSite structured data). In-place, idempotent; restores server.js on failure.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/server.js.bak-homeseo-$TS"; cd "$GSZ"
cp server.js "$BK"; echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK" "$GSZ/server.js"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR
node "$SRC/patch_homeseo.js"
node --check "$GSZ/server.js" && echo "   server.js ok"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "   --- homepage head check ---"
curl -s http://127.0.0.1:3900/ | grep -oE '<title>[^<]*</title>|<meta name="description"[^>]*>|application/ld\+json' | head
echo "DONE — homepage title + SEO (meta, OG, Organization/WebSite schema)"
