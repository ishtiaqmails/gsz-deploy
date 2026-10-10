#!/usr/bin/env bash
# Galaxy Hub — Deploy M (checkout respects product requirements): the activation email for
# amember / vendor_invite / portal products is now a REQUIRED field with a clear per-type label
# (was optional + vague), enforced in BOTH the single-item buy and the cart checkout, and the cart
# flow now actually collects that email per item (li_<i>_email). MAC / link / qty were already
# enforced. checkout_model partial only.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
CM=views/partials/checkout_model.ejs
cp -f "$CM" "$CM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$CM.bak.$TS" "$CM"; }
trap restore ERR
cp -f "$SRC/checkout_model.ejs" "$CM"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$CM','utf8'),{filename:process.cwd()+'/'+'$CM'});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy M: checkout now requires the right email per delivery type (single + cart)."
