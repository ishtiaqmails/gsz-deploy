#!/usr/bin/env bash
# GSZ — Galaxy Hub auth, done inside the customer model (no colours/layout changed):
#   1) Persistent, status-aware footer at the end of the Hub — ALWAYS shows the right
#      action: "Sign In" + "Create Account" when signed out, "Sign Out" (with who you're
#      signed in as) when signed in. No more hunting for where to sign in.
#   2) Forgot password lives INSIDE the Hub (forgotForm/resetForm) — reset by email OR
#      verified WhatsApp; /forgot + /reset answer JSON for the Hub's fetch.
#   3) Trials: "Convert to paid" (purchase) is offered again for every un-converted trial
#      (active or expired), not just the first 2 days.
# hub_model.ejs is replaced from source (its normal deploy path); account.js is string-
# patched (idempotent). Backs up, validates, auto-restores + restarts on any failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-hubauth-$TS"
cd "$GSZ"
FILES=(views/partials/hub_model.ejs routes/account.js)

echo "==> backup -> $BK"
for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR

echo "==> replace hub_model.ejs (persistent status footer + in-Hub forgot/reset)"
cp -f "$SRC/hub_model.ejs" "$GSZ/views/partials/hub_model.ejs"

echo "==> patch account.js (trials convert-always + forgot/reset AJAX)"
node "$SRC/patch_trials.js"  "$GSZ"
node "$SRC/patch_hubauth.js" "$GSZ"

echo "==> validate"
node --check "$GSZ/routes/account.js"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const p='$GSZ/views/partials/hub_model.ejs';ejs.compile(fs.readFileSync(p,'utf8'),{filename:p});console.log('   hub_model ejs ok');"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Hub footer always shows the right Sign In / Create Account / Sign Out for your status; Forgot password works inside the Hub; Trials show Convert-to-paid again."
