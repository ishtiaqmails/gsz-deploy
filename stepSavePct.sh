#!/usr/bin/env bash
# Galaxy — Deploy SavePct: product page plan pills now show a "Save X%" chip on longer plans
# (per-month saving vs the costliest-per-month plan) and a "Most Popular" ribbon on any plan the
# admin flags. In-place patch of views/product.ejs only. Idempotent; auto-restores on any error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
PV=views/product.ejs
cp -f "$PV" "$PV.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$PV.bak.$TS" "$PV"; }
trap restore ERR
node "$SRC/patch_savepct.js" "$GSZ"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$PV','utf8'),{filename:process.cwd()+'/'+'$PV'});console.log('  ejs ok');"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy SavePct: plan pills show Save% + Most-Popular ribbon (admin flag wired next)."
