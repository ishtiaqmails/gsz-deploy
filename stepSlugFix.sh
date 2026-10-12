#!/usr/bin/env bash
# #82 — Clean product slugs. Three parts:
#   1) patch routes/products.js  -> /product/:slug 301s old slugs via cs_redirects (links stay alive)
#   2) patch routes/adminCatalog.js -> new products get a clean name slug (no Date.now tail)
#   3) migrate DB -> rewrite every product slug from its clean NAME + record old->new 301s
# File patches roll back on error (trap). The DB migration runs in one transaction (all-or-nothing).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-slug-$TS"; cd "$GSZ"
P=routes/products.js; A=routes/adminCatalog.js
for f in "$P" "$A"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring route files (DB migration is transactional; nothing committed on failure)"; for f in "$P" "$A"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

node "$SRC/patch_prodredirect.js" "$GSZ"
node "$SRC/patch_sluggen.js" "$GSZ"
node --check "$GSZ/$P" && echo "   products.js ok"
node --check "$GSZ/$A" && echo "   adminCatalog.js ok"

echo "--- slug migration ---"
node "$SRC/migrate_slugs.js" "$GSZ"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — product slugs are clean; old links 301 to the new slug."
