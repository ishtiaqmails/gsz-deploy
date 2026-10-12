#!/usr/bin/env bash
# GSZ admin — Issues as a full chat (Stage A: admin side).
#   - DB: issue_messages table (idempotent) + seeds existing reports/responses into threads.
#   - routes/adminIssues.js: adds /issues/:id chat thread + /issues/:id/message reply;
#     decisions (stock/manual/fix/reject) now mirror into the thread + ping the customer.
#   - views/admin/issues.ejs: list -> "Open chat" with unread markers.
#   - views/admin/issue.ejs: NEW premium thread (bubbles, templates, product-type guidance,
#     screenshot replies, replacement actions).
# Backs up code, runs the migration, validates, restarts, restores code on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-issueschat-$TS"; cd "$GSZ"
R=routes/adminIssues.js; L=views/admin/issues.ejs; T=views/admin/issue.ejs
mkdir -p "$BK/$(dirname "$R")" "$BK/$(dirname "$L")"
cp "$GSZ/$R" "$BK/$R"; cp "$GSZ/$L" "$BK/$L"; [ -f "$GSZ/$T" ] && cp "$GSZ/$T" "$BK/$T" || true
restore(){ echo "!! FAILED — restoring code"; cp "$BK/$R" "$GSZ/$R"; cp "$BK/$L" "$GSZ/$L"; [ -f "$BK/$T" ] && cp "$BK/$T" "$GSZ/$T" || true; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "-> migration (issue_messages)"
sudo -u postgres psql gsz -v ON_ERROR_STOP=1 -f "$SRC/sql_issue_messages.sql" >/dev/null
echo "   migration ok"

cp -f "$SRC/adminIssues.js"       "$GSZ/$R"
cp -f "$SRC/admin_issues.ejs"     "$GSZ/$L"
cp -f "$SRC/adm_issue_thread.ejs" "$GSZ/$T"
node --check "$GSZ/$R" && echo "   adminIssues.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$L','$T'].forEach(function(f){ejs.compile(fs.readFileSync('$GSZ/'+f,'utf8'),{filename:'$GSZ/'+f});});console.log('   views ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — admin Issues is now a chat (thread + reply + templates + guidance). Hub side next."
