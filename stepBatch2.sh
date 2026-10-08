#!/usr/bin/env bash
# Track A / Batch 2 — Payments, Netflix, Issues, Messages premium.
set -Eeuo pipefail
GSZ=/opt/gsz
SRC=/opt/gsz-deploy/libsrc
TS=$(date +%s)

echo "== Batch 2: payments/netflix/issues/messages =="
FILES="payments netflix issues messages"
for f in $FILES; do cp -f "$GSZ/views/admin/$f.ejs" "$GSZ/views/admin/$f.ejs.bak.$TS"; done
restore(){ echo "!! failed — restoring"; for f in $FILES; do cp -f "$GSZ/views/admin/$f.ejs.bak.$TS" "$GSZ/views/admin/$f.ejs"; done; }
trap restore ERR

cp -f "$SRC/adm_payments.ejs" "$GSZ/views/admin/payments.ejs"
cp -f "$SRC/adm_netflix.ejs"  "$GSZ/views/admin/netflix.ejs"
cp -f "$SRC/adm_issues.ejs"   "$GSZ/views/admin/issues.ejs"
cp -f "$SRC/adm_messages.ejs" "$GSZ/views/admin/messages.ejs"

NODE_PATH="$GSZ/node_modules" node -e '
  const ejs=require("ejs"),fs=require("fs"),p="'"$GSZ"'/views/admin/";
  ["payments.ejs","netflix.ejs","issues.ejs","messages.ejs"].forEach(f=>{ ejs.compile(fs.readFileSync(p+f,"utf8"),{filename:p+f}); console.log("ejs ok:",f); });
'
trap - ERR

cd "$GSZ"
pm2 restart gsz --update-env >/dev/null
login=""; home=""
for i in $(seq 1 25); do
  login=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || true)
  home=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true)
  [ "$login" = "200" ] && [ "$home" = "200" ] && { echo "health OK after ${i}s"; break; }
  sleep 1
done
echo "admin/login: $login   site: $home"
echo "== batch 2 done =="
