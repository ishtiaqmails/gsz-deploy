#!/usr/bin/env bash
# Galaxy Hub — Deploy E: point "Update Household" at the Netflix Accounts Portal (not gsz-api).
# Adds nfPortal.updateHousehold() + re-points /account/tools/household/:no. No DB change.
# Portal side must expose POST /internal/household { order_no, whatsapp } (see the spec).
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
cp -f routes/account.js "routes/account.js.bak.$TS"
cp -f lib/nfPortal.js "lib/nfPortal.js.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "routes/account.js.bak.$TS" routes/account.js; cp -f "lib/nfPortal.js.bak.$TS" lib/nfPortal.js; }
trap restore ERR

node "$SRC/patch_nfhousehold.js" lib/nfPortal.js
node "$SRC/patch_household_repoint.js" "$GSZ"

node --check routes/account.js
node --check lib/nfPortal.js
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/announcements || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Galaxy Hub E: Update Household now routed to the Netflix Portal (needs Portal POST /internal/household)."
