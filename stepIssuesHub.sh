#!/usr/bin/env bash
# GSZ Issues chat — Stage B (customer side) + Verification-Bot pings.
#   - DB: add whatsapp.issue_update template (Verification Bot outbox).
#   - routes/adminIssues.js: admin->customer ping now goes via the Verification Bot
#     (wa_notifications outbox), NOT the reseller bot.
#   - routes/account.js: new claims seed their first thread message; /claims returns
#     the full thread; customer can reply (text+screenshot) + msg-screenshot route.
#   - views/partials/hub_model.ejs: Hub "requests" tab is now a two-way conversation.
# Backs up code, runs migration, validates, restarts, restores code on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-issueshub-$TS"; cd "$GSZ"
AI=routes/adminIssues.js; AC=routes/account.js; HM=views/partials/hub_model.ejs
mkdir -p "$BK/$(dirname "$AI")" "$BK/$(dirname "$HM")"
cp "$GSZ/$AI" "$BK/$AI"; cp "$GSZ/$AC" "$BK/$AC"; cp "$GSZ/$HM" "$BK/$HM"
restore(){ echo "!! FAILED — restoring code"; cp "$BK/$AI" "$GSZ/$AI"; cp "$BK/$AC" "$GSZ/$AC"; cp "$BK/$HM" "$GSZ/$HM"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "-> migration (issue_update template)"
sudo -u postgres psql gsz -v ON_ERROR_STOP=1 -f "$SRC/sql_issue_template.sql" >/dev/null
echo "   template ok"

cp -f "$SRC/adminIssues.js" "$GSZ/$AI"
node "$SRC/patch_issuethread.js" "$GSZ"
cp -f "$SRC/hub_model.ejs" "$GSZ/$HM"
node --check "$GSZ/$AI" && echo "   adminIssues.js ok"
node --check "$GSZ/$AC" && echo "   account.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const p='$GSZ/$HM';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   hub_model ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — customers can reply in the Hub; admin replies ping the customer via the Verification Bot."
