#!/usr/bin/env bash
# step99 — Batch 1: slow the order "toss" social-proof popup (first at ~2 min,
# then every 6-12 min) and bump the app.js cache version so browsers reload.
# Idempotent; rolls back app.js + store_bottom.ejs.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step99-$TS
mkdir -p "$BAK/js" "$BAK/partials"
cp "$APP/public/js/app.js" "$BAK/js/app.js"
cp "$APP/views/partials/store_bottom.ejs" "$BAK/partials/store_bottom.ejs"
restore(){ echo "!! rollback"; cp "$BAK/js/app.js" "$APP/public/js/app.js"; cp "$BAK/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR
cd "$APP"

echo "==> slow the toss timing in app.js"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/public/js/app.js'; let s=fs.readFileSync(f,'utf8');
const oldT="setTimeout(loop,180000+Math.random()*180000);},45000);";
const newT="setTimeout(loop,360000+Math.random()*360000);},120000);";
if(s.indexOf(newT)>=0){ console.log('   already slowed'); }
else if(s.indexOf(oldT)<0){ console.error('!! toss timing anchor not found'); process.exit(2); }
else { s=s.split(oldT).join(newT); fs.writeFileSync(f,s); console.log('   toss slowed (first ~2min, then 6-12min)'); }
NODE
node --check "$APP/public/js/app.js" && echo "   app.js syntax OK"

echo "==> bump app.js cache version in store_bottom.ejs"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/views/partials/store_bottom.ejs'; let s=fs.readFileSync(f,'utf8');
const m=s.match(/app\.js\?v=(\d+)/);
if(!m){ console.error('!! app.js version ref not found'); process.exit(3); }
const next=parseInt(m[1],10)+1;
s=s.replace(/app\.js\?v=\d+/, 'app.js?v='+next);
fs.writeFileSync(f,s); console.log('   app.js?v bumped to '+next);
NODE

echo "==> restart + health"; pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }
trap - ERR
echo "==> step99 OK — order toast now minutes apart. Backup: $BAK"
