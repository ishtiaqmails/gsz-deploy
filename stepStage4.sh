#!/usr/bin/env bash
# stepStage4.sh — buffer slider on /admin/payments + owner price endpoint (/api/owner/price).
#   Copies routes/ownerPrice.js, patches adminPayments.js + payments.ejs + server.js.
# Idempotent; restores (incl. the new file) on failure OR if health doesn't return.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
FILES=(routes/adminPayments.js views/admin/payments.ejs server.js)
NEWFILE=routes/ownerPrice.js
HADNEW=0; [ -f "$GSZ/$NEWFILE" ] && HADNEW=1
for f in "${FILES[@]}"; do cp -f "$GSZ/$f" "$GSZ/$f.bak.$TS"; done
restore(){ echo "!! failed — restoring";
  for f in "${FILES[@]}"; do cp -f "$GSZ/$f.bak.$TS" "$GSZ/$f"; done
  [ "$HADNEW" = "0" ] && rm -f "$GSZ/$NEWFILE" || true
  pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> copy owner price endpoint"
cp -f "$SRC/ownerPrice.js" "$GSZ/$NEWFILE"
echo "==> patch"
node "$SRC/patch_stage4.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/routes/adminPayments.js" && echo "  adminPayments.js ok"
node --check "$GSZ/routes/ownerPrice.js"    && echo "  ownerPrice.js ok"
node --check "$GSZ/server.js"               && echo "  server.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/views/admin/payments.ejs','utf8'),{filename:'$GSZ/views/admin/payments.ejs'});console.log('  payments.ejs compiles');"

trap - ERR
pm2 restart gsz --update-env >/dev/null
ok=0; for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { ok=1; echo "  health OK (${i}s)"; break; }; sleep 1; done
if [ "$ok" != "1" ]; then echo "  health FAILED — restoring"; restore; exit 1; fi

echo
echo "==> endpoint guard check (no secret must be 401)"
code=$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:3900/api/owner/price?product=test' || true)
echo "  /api/owner/price without secret -> HTTP $code  (expect 401)"
echo
echo "DONE — Buffer slider is live at /admin/payments. Owner price endpoint is live at"
echo "  GET /api/owner/price?secret=<wa_bot_webhook_secret>&product=<q>&plan=<q>&country=<CC>"
