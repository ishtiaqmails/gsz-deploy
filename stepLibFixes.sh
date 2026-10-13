#!/usr/bin/env bash
# stepLibFixes.sh — one deploy for five fixes:
#   1. Library display: country shown as a clean tag (no raw flag codes), chips show names.
#   2. Trials: no email delivery (WhatsApp only).
#   3. Trials: show OUR store product name instead of the bot's raw panel name.
#   4. Checkout: require sign-in before Buy Now (guests -> /login?next=…, resume after).
#   5. Renewal: strip any HTML wrapper a panel returns around the username/expiry.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-libfixes-$TS"; cd "$GSZ"

PG=lib/iptv/pages.js
TP=lib/trialpoll.js
TR=routes/trials.js
HM=views/partials/hub_model.ejs
CM=views/partials/checkout_model.ejs

for f in "$PG" "$TP" "$TR" "$HM" "$CM"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in "$PG" "$TP" "$TR" "$HM" "$CM"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

cp -f "$SRC/iptv/pages.js"       "$GSZ/$PG"
cp -f "$SRC/trialpoll.js"        "$GSZ/$TP"
cp -f "$SRC/trials.js"           "$GSZ/$TR"
cp -f "$SRC/hub_model.ejs"       "$GSZ/$HM"
cp -f "$SRC/checkout_model.ejs"  "$GSZ/$CM"

echo "==> syntax checks"
node --check "$GSZ/$PG" && echo "   pages.js ok"
node --check "$GSZ/$TP" && echo "   trialpoll.js ok"
node --check "$GSZ/$TR" && echo "   trials.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$GSZ/$HM','$GSZ/$CM'].forEach(p=>ejs.compile(fs.readFileSync(p,'utf8'),{filename:p}));console.log('   ejs ok');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — library tags, trials (no email + store names), checkout sign-in gate, renewal HTML strip"
