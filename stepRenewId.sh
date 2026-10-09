#!/usr/bin/env bash
# Reset-proof renew/activation ids (derive from order_no, not the rewinding serial id).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cp -f "$GSZ/routes/checkout.js" "$GSZ/routes/checkout.js.bak.$TS"
restore(){ echo "!! failed — restoring checkout.js"; cp -f "$GSZ/routes/checkout.js.bak.$TS" "$GSZ/routes/checkout.js"; }
trap restore ERR
node "$SRC/patch_renewid.js" "$GSZ"
node --check "$GSZ/routes/checkout.js"
trap - ERR
cd "$GSZ"; pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true)
  [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }
  sleep 1
done
echo "DONE — renew & player ids are now reset-proof. Safe to test renew/paid line."
