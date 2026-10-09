#!/usr/bin/env bash
# Trial delivery fix: unique outbox idempotency key + clear stale outbox/claims for a clean re-test.
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)
export PGPASSWORD="$(grep -E '^DB_PASS=' "$GSZ/.env" | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' "$GSZ/.env" | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' "$GSZ/.env" | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' "$GSZ/.env" | cut -d= -f2-)"

echo "== trial outbox idempotency fix =="
cp -f "$GSZ/lib/trialpoll.js" "$GSZ/lib/trialpoll.js.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/lib/trialpoll.js.bak.$TS" "$GSZ/lib/trialpoll.js"; }
trap restore ERR
cp -f "$SRC/trialpoll.js" "$GSZ/lib/trialpoll.js"
node --check "$GSZ/lib/trialpoll.js"
trap - ERR

echo "== clear stale outbox + claims (clean re-test) =="
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "TRUNCATE wa_notifications RESTART IDENTITY; TRUNCATE trial_claims RESTART IDENTITY;"

cd "$GSZ"; pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 25); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true)
  [ "$code" = "200" ] && { echo "health OK after ${i}s"; break; }
  sleep 1
done
echo "/api/trials: $code"
echo "== trial fix v2 done — re-test trials now; all should deliver on WhatsApp =="
