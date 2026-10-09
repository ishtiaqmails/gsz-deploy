#!/usr/bin/env bash
# Trial fix: globally-unique request_id (UNIQUE_TRIAL_REF_v1) + clear polluted test claims.
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)
export PGPASSWORD="$(grep -E '^DB_PASS=' "$GSZ/.env" | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' "$GSZ/.env" | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' "$GSZ/.env" | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' "$GSZ/.env" | cut -d= -f2-)"

echo "== trial request_id fix =="
cp -f "$GSZ/routes/trials.js" "$GSZ/routes/trials.js.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/routes/trials.js.bak.$TS" "$GSZ/routes/trials.js"; }
trap restore ERR
cp -f "$SRC/trials.js" "$GSZ/routes/trials.js"
node --check "$GSZ/routes/trials.js"
trap - ERR

echo "== clear polluted trial claims (fresh quota, fresh ids) =="
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "TRUNCATE trial_claims RESTART IDENTITY;"

cd "$GSZ"; pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 25); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true)
  [ "$code" = "200" ] && { echo "health OK after ${i}s"; break; }
  sleep 1
done
echo "/api/trials: $code"
echo "== trial fix done — re-test trials now =="
