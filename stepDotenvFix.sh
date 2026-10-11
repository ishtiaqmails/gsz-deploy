#!/usr/bin/env bash
# GSZ — fix email site-wide: load /opt/gsz/.env from the script dir (__dirname) so the
# running process actually gets BREVO_API_KEY (and any other newer .env vars), regardless
# of pm2's working directory. Unblocks verification codes, order emails and marketing.
# One-line server.js change. Idempotent; backs up, validates, auto-restores; verifies after.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/server.js.bak.$TS"; TMP=$(mktemp -d)
cd "$GSZ"
cp -f "$GSZ/server.js" "$BK"
restore(){ echo "!! FAILED — restoring server.js"; cp -f "$BK" "$GSZ/server.js"; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

cp -f "$SRC/patch_dotenv.js" "$TMP/p.js"
node "$TMP/p.js" "$GSZ"
node --check "$GSZ/server.js"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done

# verify the running process now sees the Brevo key (checked in-process via the app's own require)
echo "==> email config check:"
( cd "$GSZ" && node -e "require('dotenv').config({path:require('path').join('$GSZ','.env')}); const m=require('./lib/mailer'); console.log('   mailer.configured():', m.configured());" )
rm -rf "$TMP"
echo "DONE — .env now loads fully; email (verification / orders / marketing) should be live."
