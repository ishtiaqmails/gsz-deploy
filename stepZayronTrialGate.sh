#!/usr/bin/env bash
# stepZayronTrialGate — ordering a trial now requires a signed-in, WhatsApp-verified account
# (verification happens once at signup). Not signed in -> "Create your account"; signed in but
# unverified -> "Verify your WhatsApp". Server enforces it too. Touches routes/trial.js + public/ztrial.js.
# Safe: backup both, single-match anchors + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp routes/trial.js "$B/trial.js.bak"; cp public/ztrial.js "$B/ztrial.js.bak"
revert(){ cp "$B/trial.js.bak" routes/trial.js; cp "$B/ztrial.js.bak" public/ztrial.js; pm2 restart zayron >/dev/null 2>&1 || true; }

# ---- trial.js: expose signedIn/acctVerified on /providers + enforce the gate in POST /start ----
node - <<'APPLY'
const fs=require('fs');const F='routes/trial.js';let s=fs.readFileSync(F,'utf8');
function rep(o,n){const c=s.split(o).length-1;if(c!==1){console.error('TRIAL ANCHOR x'+c+': '+o.slice(0,50));process.exit(5);}s=s.split(o).join(n);}

// T1) /providers: add signedIn + acctVerified
rep(
`      let _vpP = null; try { _vpP = await _verifiedPhone(req); } catch (e) {}
      res.json({ ok: true, providers: out, whatsapp: (data.whatsapp || '').replace(/[^0-9]/g, ''), maxProviders: _maxP2, usedCount: _usedCount, remaining: (_maxP2 > 0 ? Math.max(0, _maxP2 - _usedCount) : null), verified: !!_vpP, verifiedLast: _vpP ? String(_vpP).slice(-4) : '' });`,
`      let _vpP = null; try { _vpP = await _verifiedPhone(req); } catch (e) {}
      const _sc = (req.session && req.session.customer) || null;
      let _av = false; if (_sc) { try { const _rr = (await pool.query('SELECT phone_verified FROM customers WHERE id=$1', [_sc.id])).rows[0]; _av = !!(_rr && _rr.phone_verified === true); } catch (e) {} }
      res.json({ ok: true, providers: out, whatsapp: (data.whatsapp || '').replace(/[^0-9]/g, ''), maxProviders: _maxP2, usedCount: _usedCount, remaining: (_maxP2 > 0 ? Math.max(0, _maxP2 - _usedCount) : null), verified: !!_vpP, verifiedLast: _vpP ? String(_vpP).slice(-4) : '', signedIn: !!_sc, acctVerified: _av });`);

// T2) POST /start: require signed-in + verified account
rep(
`      // signed-in customers: use the number on their account, no need to type it again
      const _sessCust = (req.session && req.session.customer) || null;
      const phone = normPhone(req.body.phone, req.body.cc) || (await _verifiedPhone(req)) || (_sessCust ? normPhone(_sessCust.phone) : '');`,
`      // signed-in customers: use the number on their account, no need to type it again
      const _sessCust = (req.session && req.session.customer) || null;
      // ACCOUNT-REQUIRED GATE: a trial needs a signed-in, WhatsApp-verified account
      const _isFetch0 = (req.get('X-Requested-With') === 'fetch') || (req.get('Accept') || '').indexOf('application/json') >= 0;
      let _acctVerified = false;
      if (_sessCust) { try { const _rv = (await pool.query('SELECT phone_verified FROM customers WHERE id=$1', [_sessCust.id])).rows[0]; _acctVerified = !!(_rv && _rv.phone_verified === true); } catch (e) {} }
      if (!_sessCust) { const _nx = '/account/signup?next=/server/' + encodeURIComponent(s.slug); return _isFetch0 ? res.json({ ok:false, reason:'signin', next:_nx }) : res.redirect(_nx); }
      if (!_acctVerified) { return _isFetch0 ? res.json({ ok:false, reason:'verify', next:'/account/verify-phone' }) : res.redirect('/account/verify-phone'); }
      const phone = normPhone(req.body.phone, req.body.cc) || (await _verifiedPhone(req)) || (_sessCust ? normPhone(_sessCust.phone) : '');`);

fs.writeFileSync(F,s);console.log('trial.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "trial.js patch failed"; exit 1; }

# ---- ztrial.js: show sign-in / verify prompts in the popup ----
node - <<'APPLY'
const fs=require('fs');const F='public/ztrial.js';let s=fs.readFileSync(F,'utf8');
function rep(o,n){const c=s.split(o).length-1;if(c!==1){console.error('ZTRIAL ANCHOR x'+c+': '+o.slice(0,50));process.exit(5);}s=s.split(o).join(n);}

// Z1) vars
rep(`  var VERIFIED = false; var VLAST = '';`,
`  var VERIFIED = false; var VLAST = '';
  var SIGNED_IN = false; var ACCT_VERIFIED = false;`);

// Z2) set from /providers
rep(`VERIFIED = !!d.verified; VLAST = d.verifiedLast || ''; }`,
`VERIFIED = !!d.verified; VLAST = d.verifiedLast || ''; SIGNED_IN = !!d.signedIn; ACCT_VERIFIED = !!d.acctVerified; }`);

// Z3) gate helpers + gate startDirect
rep(
`  function startDirect(p) {
    renderStarting(p);`,
`  function _gate() {
    if (!SIGNED_IN) { renderSignin(); return false; }
    if (!ACCT_VERIFIED) { renderVerifyPrompt(); return false; }
    return true;
  }
  function renderSignin() {
    var next = encodeURIComponent(location.pathname + location.search);
    card().innerHTML = '<button class="zt-x">&times;</button><span class="zt-kick">Free Trial</span><h2 class="zt-h">Create your account</h2><p class="zt-sub">Free trials are tied to your account. We verify your WhatsApp once at sign-up — after that you never enter a code again.</p><a class="zt-cta" href="/account/signup?next=' + next + '" style="text-decoration:none;text-align:center;box-sizing:border-box;display:block">Create my account</a><p class="zt-note">Already have an account? <a href="/account/login?next=' + next + '" style="color:var(--b1,#0047FF);font-weight:700">Sign in</a></p>';
    card().querySelector('.zt-x').addEventListener('click', close);
  }
  function renderVerifyPrompt() {
    card().innerHTML = '<button class="zt-x">&times;</button><span class="zt-kick">Verify</span><h2 class="zt-h">Verify your WhatsApp</h2><p class="zt-sub">Your WhatsApp number needs to be verified before you can start a trial. It only takes a moment.</p><a class="zt-cta" href="/account/verify-phone" style="text-decoration:none;text-align:center;box-sizing:border-box;display:block">Verify my number</a>';
    card().querySelector('.zt-x').addEventListener('click', close);
  }
  function startDirect(p) {
    if (!_gate()) return;
    renderStarting(p);`);

// Z4) gate renderFields (grid-pick path)
rep(
`  function renderFields(p) {
    var fields = p.fields || [];
    if (VERIFIED) { fields = fields.filter(function (fl) { return !(fl.type === 'phone' || /whats|phone|number|mobile/i.test(fl.label || '')); }); }`,
`  function renderFields(p) {
    if (!_gate()) return;
    var fields = p.fields || [];
    if (VERIFIED) { fields = fields.filter(function (fl) { return !(fl.type === 'phone' || /whats|phone|number|mobile/i.test(fl.label || '')); }); }`);

fs.writeFileSync(F,s);console.log('ztrial.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "ztrial.js patch failed - reverting"; revert; exit 1; }

node --check routes/trial.js || { echo "trial syntax error - reverting"; revert; exit 1; }
node --check public/ztrial.js || { echo "ztrial syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: trials require a signed-in, verified account (signup verifies once). healthz=200"
