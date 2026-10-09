#!/usr/bin/env bash
# Gate website trials by the bot's live /api/products trial.enabled (BOT_TRIAL_GATE_v1).
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== Trials: gate by bot trial.enabled =="
cp -f "$GSZ/routes/trials.js" "$GSZ/routes/trials.js.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/routes/trials.js.bak.$TS" "$GSZ/routes/trials.js"; }
trap restore ERR

cp -f "$SRC/trials.js" "$GSZ/routes/trials.js"
node --check "$GSZ/routes/trials.js"
trap - ERR

cd "$GSZ"
pm2 restart gsz --update-env >/dev/null
home=""; trials=""
for i in $(seq 1 25); do
  home=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true)
  trials=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true)
  [ "$home" = "200" ] && [ "$trials" = "200" ] && { echo "health OK after ${i}s"; break; }
  sleep 1
done
echo "site: $home   /api/trials: $trials"
echo "--- live /api/trials (which trials now show) ---"
curl -s http://127.0.0.1:3900/api/trials | head -c 1200; echo
echo "== trials done =="
