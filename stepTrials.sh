#!/usr/bin/env bash
# GSZ admin — premium Trials section (#78):
#   - 3 stat cards (Active trials / Claimed all-time / At limit)
#   - Trial servers config (toggle, duration, max per customer) as clean cards
#   - Customer activity: per-customer, per-IPTV usage with a one-click RESET that
#     frees that customer's quota for that server (sets counted claims -> 'reset').
# Replaces routes/adminTrials.js (whole file) + views/admin/trials.ejs (whole file).
# Backs up both, validates (node --check + ejs compile), restarts, restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-trials-$TS"; cd "$GSZ"
R=routes/adminTrials.js; V=views/admin/trials.ejs
mkdir -p "$BK/$(dirname "$R")" "$BK/$(dirname "$V")"
cp "$GSZ/$R" "$BK/$R" 2>/dev/null || true
cp "$GSZ/$V" "$BK/$V" 2>/dev/null || true
restore(){ echo "!! FAILED — restoring"; [ -f "$BK/$R" ] && cp "$BK/$R" "$GSZ/$R"; [ -f "$BK/$V" ] && cp "$BK/$V" "$GSZ/$V"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
cp -f "$SRC/adminTrials.js" "$GSZ/$R"
cp -f "$SRC/adm_trials.ejs" "$GSZ/$V"
node --check "$GSZ/$R" && echo "   adminTrials.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const p='$GSZ/$V';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   trials.ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — premium Trials: 3 cards + server config + per-customer reset."
