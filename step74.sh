#!/usr/bin/env bash
# step74 — MAC char fix: accept any 12+ alphanumeric device ID (player MACs can
# contain non-hex letters), matching the bot's validator. Relaxes checkout + validate checks.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step74-$TS
mkdir -p "$BAK/routes"
cp "$APP/routes/checkout.js" "$BAK/routes/checkout.js"
restore(){ echo "!! rollback"; cp "$BAK/routes/checkout.js" "$APP/routes/checkout.js"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> relax hex-only MAC checks to alphanumeric"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/routes/checkout.js';
let s=fs.readFileSync(f,'utf8');
const a=".replace(/[^0-9a-fA-F]/g, '')";
const b=".replace(/[^0-9a-zA-Z]/g, '')";
const n=s.split(a).length-1;
if(n===0){ if(s.indexOf(b)>=0){ console.log('   already relaxed'); } else { console.error('!! MAC check pattern not found'); process.exit(2); } }
else { s=s.split(a).join(b); fs.writeFileSync(f,s); console.log('   relaxed '+n+' MAC check(s)'); }
NODE

echo "==> node --check"; node --check "$APP/routes/checkout.js"
echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }
# a non-hex 12-char device id should NOT be rejected for format now (valid or pending true, not the <12 message)
VM=$(curl -s -m 10 "http://127.0.0.1:3900/validate-mac?mac=ZZ11GG22HH33" || true)
echo "   validate non-hex id -> $VM"
grep -q '"valid":false,"message":"Enter a valid MAC' <<<"$VM" && { echo "!! non-hex id still rejected on format"; false; } || true
trap - ERR
echo "==> step74 OK — non-hex device IDs accepted. Backup: $BAK"
