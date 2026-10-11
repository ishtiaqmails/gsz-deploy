#!/usr/bin/env bash
# Galaxy — cleanup: remove the now-unused /account/tools/entitlements route from the live app
# (Quick Access is no longer product-aware). Nothing references it anymore.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
AC=routes/account.js
cp -f "$AC" "$AC.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$AC.bak.$TS" "$AC"; }
trap restore ERR
node "$SRC/patch_rm_entitlements.js" "$GSZ"
node --check "$AC"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — dead entitlements route removed. Clean."
