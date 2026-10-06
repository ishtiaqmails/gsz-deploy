#!/usr/bin/env bash
# step46 — Mapping dropdown: hide owner-only free "trial" plans from the Bot-plan
# selector so they can never be mapped to a customer-facing plan (#8).
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step46-$TS
mkdir -p "$BAK/views/admin"
cp "$APP/views/admin/mapping.ejs" "$BAK/views/admin/mapping.ejs"
restore(){ echo "!! rollback"; cp "$BAK/views/admin/mapping.ejs" "$APP/views/admin/mapping.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> patch fillPlanType (filter out trial plans)"
node <<'NODE'
const fs=require('fs');
const f='/opt/gsz/views/admin/mapping.ejs';
let s=fs.readFileSync(f,'utf8');
const old="var plans=(b&&b.plans)||[], types=(b&&b.types)||[];";
if(s.indexOf(old)<0){ console.error('!! anchor line not found — aborting'); process.exit(2); }
if(s.indexOf("toLowerCase()!=='trial'")>=0){ console.log('   already patched'); process.exit(0); }
const neu="var plans=((b&&b.plans)||[]).filter(function(p){ return String(p.plan_key||'').toLowerCase()!=='trial' && !(Number(p.price)===0 && /trial/i.test(p.label||'')); });\n  var types=(b&&b.types)||[];";
s=s.replace(old,neu);
fs.writeFileSync(f,s);
console.log('   patched OK');
NODE

echo "==> verify"
grep -q "toLowerCase()!=='trial'" "$APP/views/admin/mapping.ejs" || { echo "!! filter not present after patch"; false; }

echo "==> ejs compile check"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("/opt/gsz/views/admin/mapping.ejs","utf8"),{filename:"/opt/gsz/views/admin/mapping.ejs"});console.log("   compile OK");'

echo "==> pm2 restart gsz"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken after restart"; false; }

trap - ERR
echo "==> step46 OK — trial plans hidden from mapping dropdown. Backup: $BAK"
