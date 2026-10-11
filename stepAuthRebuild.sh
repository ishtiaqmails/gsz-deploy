#!/usr/bin/env bash
# GSZ — Customer auth: rebuild Sign in / Create account / Forgot / Reset to a clean
# premium centered-card model (shared partials, GS×ZD logo, storefront blue→cyan), off
# the heavy store chrome. Also fix forgot routing: a no-account email now gets a clear
# "No account found" on the Forgot page instead of the reset-code page.
#   NEW:     partials/auth2_top.ejs, partials/auth2_bottom.ejs
#   REPLACED:views/account/{login,signup,forgot,reset}.ejs
#   PATCHED: routes/account.js (/forgot POST)
# (verify-email rebuilt separately.) Idempotent; backs up, renders each view to validate,
# auto-restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-authrebuild-$TS"; TMP=$(mktemp -d)
cd "$GSZ"
PATCHED=(routes/account.js)
REPL=(views/account/login.ejs views/account/signup.ejs views/account/forgot.ejs views/account/reset.ejs)
NEW=(views/partials/auth2_top.ejs views/partials/auth2_bottom.ejs)

echo "==> backup -> $BK"
for f in "${PATCHED[@]}" "${REPL[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
NEWHAD=()
for f in "${NEW[@]}"; do if [ -f "$GSZ/$f" ]; then NEWHAD+=("$f"); mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; fi; done
restore(){
  echo "!! FAILED — restoring"
  for f in "${PATCHED[@]}" "${REPL[@]}"; do cp "$BK/$f" "$GSZ/$f"; done
  for f in "${NEW[@]}"; do keep=0; for h in "${NEWHAD[@]:-}"; do [ "$h" = "$f" ] && keep=1; done; [ "$keep" = "1" ] && cp "$BK/$f" "$GSZ/$f" || rm -f "$GSZ/$f"; done
  pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."
}
trap 'restore' ERR

echo "==> copy partials + views"
cp -f "$SRC/auth2_top.ejs"    "$GSZ/views/partials/auth2_top.ejs"
cp -f "$SRC/auth2_bottom.ejs" "$GSZ/views/partials/auth2_bottom.ejs"
cp -f "$SRC/acc_login.ejs"    "$GSZ/views/account/login.ejs"
cp -f "$SRC/acc_signup.ejs"   "$GSZ/views/account/signup.ejs"
cp -f "$SRC/acc_forgot.ejs"   "$GSZ/views/account/forgot.ejs"
cp -f "$SRC/acc_reset.ejs"    "$GSZ/views/account/reset.ejs"

echo "==> patch forgot route"
cp -f "$SRC/patch_forgot.js" "$TMP/p.js"
node "$TMP/p.js" "$GSZ"

echo "==> validate (render each view + check route)"
node --check "$GSZ/routes/account.js"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');const d={title:'t',heading:'h',sub:'s',error:null,sent:false,email:'',next:'',idf:'',form:{},countries:[{iso:'PK',code:'92',name:'Pakistan'}]};['login','signup','forgot','reset'].forEach(function(f){const p='$GSZ/views/account/'+f+'.ejs';ejs.render(fs.readFileSync(p,'utf8'),d,{filename:p});console.log('    render ok '+f)})"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
rm -rf "$TMP"
echo "DONE — customer Sign in / Create account / Forgot / Reset rebuilt premium; no-account routing fixed."
