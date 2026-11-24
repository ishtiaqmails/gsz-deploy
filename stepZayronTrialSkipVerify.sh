#!/usr/bin/env bash
# stepZayronTrialSkipVerify — don't re-verify a trial for a signed-in customer whose account number
# is already verified (they confirmed it at signup). Anonymous / unverified visitors still verify.
# Safe: backup, single-match anchor + auto-revert, node --check, restart zayron.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp routes/trial.js "$B/trial.js.bak"
revert(){ cp "$B/trial.js.bak" routes/trial.js; pm2 restart zayron >/dev/null 2>&1 || true; }

node - <<'APPLY'
const fs = require('fs'); const F = 'routes/trial.js';
let s = fs.readFileSync(F, 'utf8');
const o = "      const _otpOn = await _isOtpOn();\n      if (_otpOn && phone) {";
const n = "      const _otpOn = await _isOtpOn();\n" +
  "      // a signed-in customer whose account number is already verified doesn't re-verify for a trial\n" +
  "      let _skipOtp = false;\n" +
  "      if (_sessCust) { try { const _cv = (await pool.query('SELECT phone_verified, phone FROM customers WHERE id=$1', [_sessCust.id])).rows[0]; if (_cv && _cv.phone_verified && String(_cv.phone || '').replace(/[^0-9]/g, '') === String(phone || '').replace(/[^0-9]/g, '')) _skipOtp = true; } catch (e) {} }\n" +
  "      if (_otpOn && phone && !_skipOtp) {";
const c = s.split(o).length - 1;
if (c !== 1) { console.error('ANCHOR x' + c); process.exit(5); }
fs.writeFileSync(F, s.split(o).join(n));
console.log('trial.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed"; exit 1; }

node --check routes/trial.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: signed-in verified customers skip trial re-verification (others still verify). healthz=200"
