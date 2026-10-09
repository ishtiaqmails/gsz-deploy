#!/usr/bin/env bash
# Reset-proof order_no: create independent order_no_seq (past used range) + patch generation/retry.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
export PGPASSWORD="$(grep -E '^DB_PASS=' "$GSZ/.env" | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' "$GSZ/.env" | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' "$GSZ/.env" | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' "$GSZ/.env" | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "== 1) create independent order_no sequence, started past all used numbers (>=2000) =="
Q -v ON_ERROR_STOP=1 -c "CREATE SEQUENCE IF NOT EXISTS order_no_seq;"
Q -v ON_ERROR_STOP=1 -c "SELECT setval('order_no_seq', GREATEST(1999, (SELECT last_value FROM order_no_seq)), true);" >/dev/null
echo "next order_no will be: GSZ-$(Q -tAc "SELECT last_value+1 FROM order_no_seq")"

echo "== 2) patch checkout.js (generation + collision retry) =="
cp -f "$GSZ/routes/checkout.js" "$GSZ/routes/checkout.js.bak.$TS"
restore(){ echo "!! failed — restoring checkout.js"; cp -f "$GSZ/routes/checkout.js.bak.$TS" "$GSZ/routes/checkout.js"; }
trap restore ERR
node "$SRC/patch_ordernum.js" "$GSZ"
node --check "$GSZ/routes/checkout.js"
trap - ERR

cd "$GSZ"; pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true)
  [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }
  sleep 1
done
echo "DONE — new orders are GSZ-2000+ from an independent counter that resets can't rewind."
