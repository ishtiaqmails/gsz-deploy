#!/usr/bin/env bash
# stepIbanAccount.sh — the REAL pay-methods handler is routes/account.js:457 (requireLogin, emits logo).
# Extend its existing payment_logos read (pay-logos-v3) to also attach extra_label/extra_value.
# Modal render (checkout_model.ejs) is already live, so this completes the chain. Bot untouched.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=routes/account.js
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .gszm_p.js; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> patching $F (attach extra_label/extra_value in pay-logos-v3)"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
const file = 'routes/account.js';
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf('_xv[m.key]') >= 0) { console.log('  already patched'); process.exit(0); }
const A = "const _lg=(await pool.query('SELECT key, logo, sort FROM payment_logos')).rows; const _lm={},_sm={}; _lg.forEach(function(r){ _lm[r.key]=r.logo; _sm[r.key]=(r.sort==null?100:r.sort); }); methods.forEach(function(m){ if(_lm[m.key]) m.logo=_lm[m.key]; });";
const B = "const _lg=(await pool.query('SELECT key, logo, sort, extra_label, extra_value FROM payment_logos')).rows; const _lm={},_sm={},_xl={},_xv={}; _lg.forEach(function(r){ _lm[r.key]=r.logo; _sm[r.key]=(r.sort==null?100:r.sort); _xl[r.key]=r.extra_label; _xv[r.key]=r.extra_value; }); methods.forEach(function(m){ if(_lm[m.key]) m.logo=_lm[m.key]; if(_xv[m.key]){ m.extra_label=_xl[m.key]||'IBAN'; m.extra_value=_xv[m.key]; } });";
const n = s.split(A).length - 1;
if (n !== 1) throw new Error('anchor found ' + n + ' times (need 1)');
s = s.split(A).join(B);
fs.writeFileSync(file, s);
console.log('  patched: pay-logos-v3 now attaches extra_label/extra_value');
JS
node .gszm_p.js

echo "==> validating"
node --check routes/account.js
rm -f .gszm_p.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — pay-methods now sends IBAN; the modal will show it under the account."
