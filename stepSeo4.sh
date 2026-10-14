#!/usr/bin/env bash
# stepSeo4.sh — enrich homepage Organization schema (sameAs socials + WhatsApp contactPoint).
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-seo4-$TS"; cd "$GSZ"
SV=server.js
mkdir -p "$BK"; cp "$GSZ/$SV" "$BK/$SV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$SV" "$GSZ/$SV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch server.js (Organization schema)"
node "$SRC/patch_seo4.js" "$GSZ"
node --check "$GSZ/$SV" && echo "   server.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "   schema check:"; curl -s http://127.0.0.1:3900/ | grep -o 'sameAs[^]]*]' | head -1
echo "DONE — Organization schema now carries your socials + WhatsApp contact."
