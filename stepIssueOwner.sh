#!/usr/bin/env bash
# Reroute issue OWNER alerts (new request / customer reply) off the reseller bot
# and onto the Verification Bot (wa_notifications -> wa_bot_send_url, to wa_owner_numbers).
# Adds the owner-alert template, patches routes/account.js, validates, restarts.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-issueowner-$TS"; cd "$GSZ"
AC=routes/account.js
mkdir -p "$BK/$(dirname "$AC")"; cp "$GSZ/$AC" "$BK/$AC"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$AC" "$GSZ/$AC"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
echo "-> migration (owner-alert template)"
sudo -u postgres psql gsz -v ON_ERROR_STOP=1 -f "$SRC/sql_issue_owner_template.sql" >/dev/null
echo "   template ok"
node "$SRC/patch_issueowner.js" "$GSZ"
node --check "$GSZ/$AC" && echo "   account.js ok"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — issue owner alerts now send from the Verification Bot; reseller bot no longer messages for issues."
