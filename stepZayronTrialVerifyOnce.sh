#!/usr/bin/env bash
# stepZayronTrialVerifyOnce — one-time WhatsApp verification. Once a number is confirmed (trial code
# or a signed-in verified account), that browser/account is never asked for the number OR a code again:
#  - sets a long-lived `zv` cookie on successful verify
#  - _verifiedPhone(req) resolves a trusted number from session account OR the zv cookie
#  - GET /trial/start shows a one-tap "Start my free trial" (no number field) when verified (?new=1 overrides)
#  - POST /trial/start uses the verified number and skips OTP
# Safe: backup, 6 single-match anchors + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp routes/trial.js "$B/trial.js.bak"
revert(){ cp "$B/trial.js.bak" routes/trial.js; pm2 restart zayron >/dev/null 2>&1 || true; }

node - <<'APPLY'
const fs = require('fs'); const F = 'routes/trial.js';
let s = fs.readFileSync(F, 'utf8');
function rep(o, n){ const c = s.split(o).length - 1; if (c !== 1){ console.error('ANCHOR x'+c+': '+o.slice(0,55)); process.exit(5);} s = s.split(o).join(n); }

// 1) add _verifiedPhone helper
rep(
`  async function _isOtpOn(){try{const r=await pool.query("SELECT v FROM otp_status WHERE k='otp_enabled'");return r.rows.length&&r.rows[0].v==='1';}catch(e){return false;}}`,
`  async function _isOtpOn(){try{const r=await pool.query("SELECT v FROM otp_status WHERE k='otp_enabled'");return r.rows.length&&r.rows[0].v==='1';}catch(e){return false;}}
  async function _verifiedPhone(req){
    try{
      const sc=(req.session&&req.session.customer)||null;
      if(sc){ const r=await pool.query('SELECT phone,phone_verified FROM customers WHERE id=$1',[sc.id]); if(r.rows[0]&&r.rows[0].phone_verified&&r.rows[0].phone) return String(r.rows[0].phone); }
      const zv=(req.cookies&&req.cookies.zv)?String(req.cookies.zv).replace(/[^0-9]/g,''):'';
      if(zv&&zv.length>=8){
        const a=await pool.query("SELECT 1 FROM customers WHERE regexp_replace(phone,'[^0-9]','','g')=$1 AND phone_verified=true LIMIT 1",[zv]); if(a.rows.length) return zv;
        const b=await pool.query("SELECT 1 FROM trials WHERE regexp_replace(phone,'[^0-9]','','g')=$1 AND otp_verified=true LIMIT 1",[zv]); if(b.rows.length) return zv;
      }
    }catch(e){}
    return null;
  }`);

// 2) GET /trial/start → one-tap confirm when already verified
rep(
`  router.get('/start', async (req, res) => {
    try {
      const s = await eligibleServer(String(req.query.s || ''));
      if (!s) return res.redirect('/contact');
      const data = await getPublicData();`,
`  router.get('/start', async (req, res) => {
    try {
      const s = await eligibleServer(String(req.query.s || ''));
      if (!s) return res.redirect('/contact');
      const data = await getPublicData();
      // already verified on this browser/account -> one-tap confirm, no number, no code
      if (String(req.query.new || '') !== '1') {
        const _vp = await _verifiedPhone(req);
        if (_vp) {
          const _last = String(_vp).slice(-4);
          return page(res, data, 'Free trial — ' + s.n + ' — Zayron',
            '<div style="text-align:center;margin-bottom:6px">' +
            '<h1 style="font-size:28px;margin:0 0 8px">Free trial — ' + escAttr(s.n) + '</h1>' +
            '<p class="sec-p" style="margin:0 auto 22px">Your WhatsApp is already verified. We will set up your free trial and send the login to WhatsApp ending ••• ' + escAttr(_last) + '.</p>' +
            '</div>' +
            '<form method="post" action="/trial/start" style="background:var(--card,#fff);border:1px solid var(--line);border-radius:16px;padding:22px;text-align:center">' +
            '<input type="hidden" name="s" value="' + escAttr(s.slug) + '">' +
            '<button type="submit" class="btn white" style="width:100%;justify-content:center;font-size:16px;padding:14px">Start my free trial</button>' +
            '<div style="font-size:12px;color:var(--muted,#5d6b8c);margin-top:14px"><a href="/trial/start?s=' + escAttr(s.slug) + '&new=1" style="color:var(--muted,#5d6b8c)">Use a different number</a></div>' +
            '</form>');
        }
      }`);

// 3) POST /trial/start → resolve the verified number
rep(
`      const _sessCust = (req.session && req.session.customer) || null;
      const phone = normPhone(req.body.phone, req.body.cc) || (_sessCust ? normPhone(_sessCust.phone) : '');`,
`      const _sessCust = (req.session && req.session.customer) || null;
      const phone = normPhone(req.body.phone, req.body.cc) || (await _verifiedPhone(req)) || (_sessCust ? normPhone(_sessCust.phone) : '');`);

// 4) POST /trial/start → skip OTP for any verified number (account or browser)
rep(
`      // a signed-in customer whose account number is already verified doesn't re-verify for a trial
      let _skipOtp = false;
      if (_sessCust) { try { const _cv = (await pool.query('SELECT phone_verified, phone FROM customers WHERE id=$1', [_sessCust.id])).rows[0]; if (_cv && _cv.phone_verified && String(_cv.phone || '').replace(/[^0-9]/g, '') === String(phone || '').replace(/[^0-9]/g, '')) _skipOtp = true; } catch (e) {} }`,
`      // a verified number (signed-in account OR this browser) doesn't re-verify for a trial
      let _skipOtp = false;
      try { const _vp = await _verifiedPhone(req); if (_vp && String(_vp).replace(/[^0-9]/g, '') === String(phone || '').replace(/[^0-9]/g, '')) _skipOtp = true; } catch (e) {}`);

// 5a) verify route → fetch the phone so we can remember it
rep(
`      const r = await pool.query('SELECT t.id, t.otp_code, t.otp_expires, t.server_id, s.reseller_pid, s.bot_sku FROM trials t LEFT JOIN servers s ON s.id=t.server_id WHERE t.claim_token=$1', [token]);`,
`      const r = await pool.query('SELECT t.id, t.phone, t.otp_code, t.otp_expires, t.server_id, s.reseller_pid, s.bot_sku FROM trials t LEFT JOIN servers s ON s.id=t.server_id WHERE t.claim_token=$1', [token]);`);

// 5b) verify success → set the long-lived verified-number cookie
rep(
`      await pool.query('UPDATE trials SET otp_verified=true WHERE id=$1', [t.id]);`,
`      await pool.query('UPDATE trials SET otp_verified=true WHERE id=$1', [t.id]);
      try { if (t.phone) res.cookie('zv', String(t.phone).replace(/[^0-9]/g, ''), { httpOnly: true, sameSite: 'lax', maxAge: 365 * 864e5 }); } catch (e) {}`);

fs.writeFileSync(F, s);
console.log('trial.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed"; exit 1; }

node --check routes/trial.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: verify once -> trial never asks for the number or a code again on this browser/account. healthz=200"
