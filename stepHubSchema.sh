#!/usr/bin/env bash
# stepHubSchema.sh — add CollectionPage+Breadcrumb JSON-LD to content hub list pages.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"; F=routes/content.js
cp -f "$F" "$F.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$F.bak.$TS" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR
node "$SRC/patch_hubschema.js" "$GSZ"
node --check "$GSZ/$F" && echo "  content.js ok"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo "==> SEO QA re-run"; sleep 2; node "$GSZ/lib/seo_qa.js" 3900 | tail -14
echo "DONE"
