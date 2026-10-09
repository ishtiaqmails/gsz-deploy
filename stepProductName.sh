#!/usr/bin/env bash
# Add productName to submit-order payloads (single + cart).
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== add productName to submit-order =="
cp -f "$GSZ/routes/checkout.js" "$GSZ/routes/checkout.js.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/routes/checkout.js.bak.$TS" "$GSZ/routes/checkout.js"; }
trap restore ERR

node "$SRC/patch_productname.js" "$GSZ"
node --check "$GSZ/routes/checkout.js"
trap - ERR

cd "$GSZ"; pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 25); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true)
  [ "$code" = "200" ] && { echo "health OK after ${i}s"; break; }
  sleep 1
done
echo "site: $code"
echo "--- confirm both inserted ---"
grep -n "productName:" "$GSZ/routes/checkout.js"
echo "== productName done =="
