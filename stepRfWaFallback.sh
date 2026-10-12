#!/usr/bin/env bash
# Renew: _rfWa(c) now prefers customers.wa_number (what the order was placed with) before the
# newer identity-link number, so amember/iptv renew lights up for customers without an identity
# link. routes/account.js only.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-rfwa-$TS"; cd "$GSZ"
R=routes/account.js
mkdir -p "$BK/$(dirname "$R")"; cp "$GSZ/$R" "$BK/$R"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$R" "$GSZ/$R"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_rfwafallback.js" "$GSZ"
node --check "$GSZ/$R" && echo "   account.js ok"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — renew subscription check now resolves the customer's wa_number; amember renew should light up."
