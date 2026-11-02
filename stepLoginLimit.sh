#!/usr/bin/env bash
# stepLoginLimit.sh — add a fail-safe brute-force throttle to the password login. Keyed by the
# real client IP (CF-Connecting-IP behind Cloudflare). Only triggers after 10 failed logins in
# 15 min; a success clears it; it fails OPEN so it can never block a legit login on its own error.
# TEST AFTER DEPLOY: log in once to confirm sign-in still works.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
AC="$GSZ/routes/account.js"; LL="$GSZ/lib/loginlimit.js"; TS=$(date +%s)
[ -f "$AC" ] || { echo "no account.js"; exit 1; }
cp -f "$AC" "$AC.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$AC.xbak.$TS" "$AC"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> deploy lib/loginlimit.js"; cp -f "$DEPLOY/lib/loginlimit.js" "$LL"; node --check "$LL"

echo "==> patch routes/account.js /login (blocked-check + fail + clear)"
export AC
node <<'NODE'
const fs=require('fs'); const AC=process.env.AC; let s=fs.readFileSync(AC,'utf8');
if(s.indexOf('loginlimit')>=0){ console.log('   already patched'); process.exit(0); }
const K="req.headers['cf-connecting-ip']||req.ip";
function one(oldS,newS){ if(s.split(oldS).length-1!==1) throw new Error('anchor not unique: '+oldS.slice(0,50)); s=s.split(oldS).join(newS); }
// 1) block before credential lookup
one(
  "if (!idf || !req.body.password) return re('Enter your email or phone, and your password.');",
  "if (!idf || !req.body.password) return re('Enter your email or phone, and your password.');\n    try { if (require('../lib/loginlimit').blocked("+K+")) return re('Too many attempts. Please wait a few minutes and try again.'); } catch (e) {}");
// 2) count a failure on bad credentials
one(
  "if (!c || !verifyPw(req.body.password, c.pass_hash)) return re('Those details are incorrect. Check your email/phone and password.');",
  "if (!c || !verifyPw(req.body.password, c.pass_hash)) { try { require('../lib/loginlimit').fail("+K+"); } catch (e) {} return re('Those details are incorrect. Check your email/phone and password.'); }");
// 3) clear on success
one(
  "await pool.query('UPDATE customers SET last_login=now() WHERE id=$1', [c.id]);",
  "await pool.query('UPDATE customers SET last_login=now() WHERE id=$1', [c.id]);\n      try { require('../lib/loginlimit').ok("+K+"); } catch (e) {}");
fs.writeFileSync(AC,s); console.log('   /login throttled (fail-safe)');
NODE

echo "==> check + restart + health"
node --check "$AC"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — login brute-force throttle live. NOW TEST: log in once to confirm sign-in works. Backup: $AC.xbak.$TS"
