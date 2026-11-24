#!/usr/bin/env bash
# stepZayronAccountAuth — add Forgot Password + Change-Number (with re-verify) to the customer account.
# Reuses the Verification Bot (otp_outbox). File-based anchors so account.js template literals stay intact.
# Safe: backup, single-match anchors + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp routes/account.js "$B/account.js.bak"
revert(){ cp "$B/account.js.bak" routes/account.js; pm2 restart zayron >/dev/null 2>&1 || true; }
TMP="$(mktemp -d)"

# ---- Edit 1: Forgot-password link on the sign-in page ----
cat > "$TMP/o1" <<'O1'
      body: loginForm({ next: req.query.next || '' })
O1
cat > "$TMP/n1" <<'N1'
      body: loginForm({ next: req.query.next || '' }) + '<p style="text-align:center;margin:14px 0 0;font-size:13px"><a href="/account/forgot" style="color:#0047FF;text-decoration:none">Forgot password?</a></p>'
N1

# ---- Edit 2: new routes (forgot/reset + change-number/verify-phone) before `return router;` ----
cat > "$TMP/o2" <<'O2'
  return router;
};
O2
cat > "$TMP/n2" <<'N2'
  // ---------- FORGOT PASSWORD ----------
  function phoneHostJs(hostId, valId){
    return `<script src="/static/zphone.js"></script><script>(function(){function go(){var h=document.getElementById('${hostId}'),v=document.getElementById('${valId}');if(!h||!window.ZPhone)return setTimeout(go,60);if(h.dataset.m)return;h.dataset.m=1;var p=window.ZPhone.mount(h,{placeholder:'300 1234567'});var f=h.closest('form');if(f)f.addEventListener('submit',function(e){v.value=p.getE164();if(!v.value){e.preventDefault();}});}if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',go);else go();})();</script>`;
  }
  function forgotForm(v){ v=v||{}; return `
<form method="post" action="/account/forgot">
  <div class="acc-f"><label>WhatsApp number</label><div id="fpHost"></div><input type="hidden" name="phone" id="fpVal"></div>
  <button class="acc-go" type="submit">Send reset code</button>
</form>
<p style="text-align:center;margin:14px 0 0;font-size:13px"><a href="/account/login" style="color:#0047FF;text-decoration:none">Back to sign in</a></p>
${phoneHostJs('fpHost','fpVal')}`; }
  router.get('/forgot', async (req, res) => {
    if (me(req)) return res.redirect('/account');
    res.send(shellPage('Reset password — Zayron', authPage({ kicker:'Reset', title:'Forgot your password?', sub:'Enter your WhatsApp number and we will send a reset code.', body: forgotForm({}) }), await deps.getPublicData(), { noindex:true }));
  });
  router.post('/forgot', body, async (req, res) => {
    const phone = digits((req.body||{}).phone);
    const fail = async (error) => res.send(shellPage('Reset password — Zayron', authPage({ kicker:'Reset', title:'Forgot your password?', sub:'Enter your WhatsApp number and we will send a reset code.', error, body: forgotForm({}) }), await deps.getPublicData(), { noindex:true }));
    if (!phone || phone.length < 10) return fail('Please enter a valid WhatsApp number.');
    try {
      const r = await pool.query('SELECT id, phone, name FROM customers WHERE phone=$1', [phone]);
      const c = r.rows[0];
      if (!c) return fail('We could not find an account with that number.');
      const code = String(Math.floor(100000 + Math.random() * 900000));
      await pool.query("UPDATE customers SET otp_code=$1, otp_expires=now() + interval '10 minutes' WHERE id=$2", [code, c.id]);
      await pool.query("INSERT INTO otp_outbox (phone, body, status) VALUES ($1,$2,'queued')", [c.phone, 'Your Zayron password reset code is: ' + code + '. It expires in 10 minutes.']);
      req.session.reset = { id: c.id, phone: c.phone, name: c.name };
      return res.redirect('/account/reset');
    } catch (e) { return fail('Something went wrong. Please try again.'); }
  });
  function resetForm(error){ return authPage({ kicker:'Reset', title:'Enter your code', sub:'We sent a 6-digit code on WhatsApp. Enter it with your new password.', error, body: `
<form method="post" action="/account/reset">
  <div class="acc-f"><label>Verification code</label><input name="code" inputmode="numeric" maxlength="6" placeholder="123456" style="letter-spacing:4px;font-size:18px"></div>
  <div class="acc-f"><label>New password</label><input name="password" type="password" placeholder="At least 8 characters"></div>
  <button class="acc-go" type="submit">Reset &amp; sign in</button>
</form>` }); }
  router.get('/reset', async (req, res) => {
    if (!req.session.reset) return res.redirect('/account/forgot');
    res.send(shellPage('Reset password — Zayron', resetForm(''), await deps.getPublicData(), { noindex:true }));
  });
  router.post('/reset', body, async (req, res) => {
    const rs = req.session.reset;
    if (!rs) return res.redirect('/account/forgot');
    const code = String((req.body||{}).code||'').replace(/[^0-9]/g,'');
    const pass = String((req.body||{}).password||'');
    const fail = async (error) => res.send(shellPage('Reset password — Zayron', resetForm(error), await deps.getPublicData(), { noindex:true }));
    if (pass.length < 8) return fail('Password must be at least 8 characters.');
    try {
      const r = await pool.query('SELECT otp_code, otp_expires, phone, name FROM customers WHERE id=$1', [rs.id]);
      const row = r.rows[0];
      if (!row || !row.otp_code || (row.otp_expires && new Date(row.otp_expires) < new Date())) return fail('That code has expired. Please request a new one.');
      if (code !== row.otp_code) return fail('That code is not right. Please try again.');
      const hash = bcrypt.hashSync(pass, 10);
      await pool.query('UPDATE customers SET pass_hash=$1, otp_code=null, otp_expires=null, phone_verified=true, last_login_at=now() WHERE id=$2', [hash, rs.id]);
      req.session.customer = { id: rs.id, phone: row.phone, name: row.name };
      delete req.session.reset;
      return res.redirect('/account');
    } catch (e) { return fail('Something went wrong. Please try again.'); }
  });

  // ---------- CHANGE NUMBER (re-verify) ----------
  router.post('/settings/phone', requireLogin, body, async (req, res) => {
    const c = me(req);
    const newPhone = digits((req.body||{}).phone);
    if (!newPhone || newPhone.length < 10 || newPhone.length > 15) { req.session.flash = 'Please enter a valid WhatsApp number.'; return res.redirect('/account/settings'); }
    try {
      const dup = await pool.query('SELECT id FROM customers WHERE phone=$1 AND id<>$2', [newPhone, c.id]);
      if (dup.rows.length) { req.session.flash = 'That number is already used by another account.'; return res.redirect('/account/settings'); }
      const code = String(Math.floor(100000 + Math.random() * 900000));
      await pool.query("UPDATE customers SET phone=$1, phone_verified=false, otp_code=$2, otp_expires=now() + interval '10 minutes' WHERE id=$3", [newPhone, code, c.id]);
      await pool.query("INSERT INTO otp_outbox (phone, body, status) VALUES ($1,$2,'queued')", [newPhone, 'Your Zayron verification code is: ' + code + '. It expires in 10 minutes.']);
      req.session.customer.phone = newPhone;
      return res.redirect('/account/verify-phone');
    } catch (e) { req.session.flash = 'Could not update your number. Please try again.'; return res.redirect('/account/settings'); }
  });
  function verifyPhonePage(c, error){ return dashPage(c, 'settings', `
<div class="za-card">
  <p class="za-hd">Verify your WhatsApp</p>
  ${error ? '<p style="color:#c0392b;font-size:13px;margin:0 0 10px">'+esc(error)+'</p>' : ''}
  <p style="font-size:13.5px;color:#475569;margin:0 0 12px">We sent a 6-digit code on WhatsApp to <b>+${esc(c.phone)}</b>. Enter it to confirm your number. You cannot start trials or orders until it is verified.</p>
  <form method="post" action="/account/verify-phone">
    <input name="code" inputmode="numeric" maxlength="6" placeholder="123456" style="letter-spacing:4px;font-size:18px;width:100%;padding:11px 13px;border:1px solid #e2ebfa;border-radius:11px;margin-bottom:10px">
    <button type="submit" style="background:#0047FF;color:#fff;border:0;border-radius:11px;padding:12px 16px;font-weight:700;cursor:pointer">Verify number</button>
  </form>
  <form method="post" action="/account/verify-phone/resend" style="margin-top:10px"><button type="submit" style="background:none;border:0;color:#0047FF;cursor:pointer;padding:0;font:inherit">Resend code</button></form>
</div>`); }
  router.get('/verify-phone', requireLogin, async (req, res) => {
    const c = me(req); const err = req.session.flash; delete req.session.flash;
    res.send(shellPage('Verify your number — Zayron', verifyPhonePage(c, err || ''), await deps.getPublicData(), { noindex:true }));
  });
  router.post('/verify-phone', requireLogin, body, async (req, res) => {
    const c = me(req);
    const code = String((req.body||{}).code||'').replace(/[^0-9]/g,'');
    try {
      const r = await pool.query('SELECT otp_code, otp_expires FROM customers WHERE id=$1', [c.id]);
      const row = r.rows[0];
      if (!row || !row.otp_code || (row.otp_expires && new Date(row.otp_expires) < new Date())) return res.send(shellPage('Verify your number — Zayron', verifyPhonePage(c, 'That code has expired. Tap Resend.'), await deps.getPublicData(), { noindex:true }));
      if (code !== row.otp_code) return res.send(shellPage('Verify your number — Zayron', verifyPhonePage(c, 'That code is not right. Please try again.'), await deps.getPublicData(), { noindex:true }));
      await pool.query('UPDATE customers SET phone_verified=true, otp_code=null, otp_expires=null WHERE id=$1', [c.id]);
      req.session.flash = 'Your WhatsApp number is verified.';
      return res.redirect('/account/settings');
    } catch (e) { return res.send(shellPage('Verify your number — Zayron', verifyPhonePage(c, 'Something went wrong. Please try again.'), await deps.getPublicData(), { noindex:true })); }
  });
  router.post('/verify-phone/resend', requireLogin, async (req, res) => {
    const c = me(req);
    try {
      const code = String(Math.floor(100000 + Math.random() * 900000));
      await pool.query("UPDATE customers SET otp_code=$1, otp_expires=now() + interval '10 minutes' WHERE id=$2", [code, c.id]);
      await pool.query("INSERT INTO otp_outbox (phone, body, status) VALUES ($1,$2,'queued')", [c.phone, 'Your Zayron verification code is: ' + code + '. It expires in 10 minutes.']);
    } catch (e) {}
    return res.redirect('/account/verify-phone');
  });

  return router;
};
N2

# ---- Edit 3: Settings page — verification status + change-number form ----
cat > "$TMP/o3" <<'O3'
  router.get('/settings', requireLogin, async (req, res) => {
    const c = me(req);
    let row = {};
    try { const r = await pool.query('SELECT name, phone FROM customers WHERE id=$1', [c.id]); row = r.rows[0] || {}; } catch (e) {}
    const inner = `
<div class="za-card">
  <p class="za-hd">Account details</p>
  <table style="width:100%;font-size:13.5px;table-layout:fixed">
    <tr><td style="color:#64748b;padding:7px 0;width:42%">Name</td><td style="text-align:right">${esc(row.name || '—')}</td></tr>
    <tr><td style="color:#64748b;padding:7px 0">WhatsApp</td><td style="text-align:right;font-family:ui-monospace,monospace;font-size:12.5px">+${esc(row.phone || '')}</td></tr>

  </table>
  <p style="margin:12px 0 0;font-size:12px;color:#94a3b8">Need to change something? Message us on WhatsApp and we'll update it for you.</p>
</div>`;
    res.send(shellPage('Settings — Zayron', dashPage(c, 'settings', inner), await deps.getPublicData(), { noindex: true }));
  });
O3
cat > "$TMP/n3" <<'N3'
  router.get('/settings', requireLogin, async (req, res) => {
    const c = me(req);
    let row = {};
    try { const r = await pool.query('SELECT name, phone, phone_verified FROM customers WHERE id=$1', [c.id]); row = r.rows[0] || {}; } catch (e) {}
    const flash = req.session.flash; delete req.session.flash;
    const verified = !!row.phone_verified;
    const inner = `
${flash ? '<div class="za-card" style="border-color:#bbf7d0;background:#f0fdf6;color:#0e9257;font-size:13.5px">'+esc(flash)+'</div>' : ''}
<div class="za-card">
  <p class="za-hd">Account details</p>
  <table style="width:100%;font-size:13.5px;table-layout:fixed">
    <tr><td style="color:#64748b;padding:7px 0;width:42%">Name</td><td style="text-align:right">${esc(row.name || '—')}</td></tr>
    <tr><td style="color:#64748b;padding:7px 0">WhatsApp</td><td style="text-align:right;font-family:ui-monospace,monospace;font-size:12.5px">+${esc(row.phone || '')}</td></tr>
    <tr><td style="color:#64748b;padding:7px 0">Status</td><td style="text-align:right">${verified ? '<span style="color:#0e9257;font-weight:600">Verified ✓</span>' : '<span style="color:#c0392b;font-weight:600">Not verified</span>'}</td></tr>
  </table>
  ${verified ? '' : '<p style="margin:12px 0 0;font-size:13px"><a href="/account/verify-phone" style="color:#0047FF;font-weight:600;text-decoration:none">Verify your number now &rarr;</a> You cannot start trials or orders until your WhatsApp is verified.</p>'}
</div>
<div class="za-card">
  <p class="za-hd">Change WhatsApp number</p>
  <p style="font-size:13px;color:#475569;margin:0 0 12px">Enter a new WhatsApp number. We will send a code to confirm it — your orders are paused until the new number is verified.</p>
  <form method="post" action="/account/settings/phone">
    <div id="cpHost"></div><input type="hidden" name="phone" id="cpVal">
    <button type="submit" style="margin-top:12px;background:#0047FF;color:#fff;border:0;border-radius:11px;padding:11px 16px;font-weight:700;cursor:pointer">Change &amp; verify number</button>
  </form>
  <script src="/static/zphone.js"></script>
  <script>(function(){function go(){var h=document.getElementById('cpHost'),v=document.getElementById('cpVal');if(!h||!window.ZPhone)return setTimeout(go,60);if(h.dataset.m)return;h.dataset.m=1;var p=window.ZPhone.mount(h,{placeholder:'300 1234567'});var f=h.closest('form');if(f)f.addEventListener('submit',function(e){v.value=p.getE164();if(!v.value){e.preventDefault();}});}if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',go);else go();})();</script>
</div>`;
    res.send(shellPage('Settings — Zayron', dashPage(c, 'settings', inner), await deps.getPublicData(), { noindex: true }));
  });
N3

node - "$TMP" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2]; const F='routes/account.js';
let s=fs.readFileSync(F,'utf8');
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function rep(of,nf){ const o=rd(of), n=rd(nf); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR '+of+' x'+c); process.exit(5); } s=s.split(o).join(n); }
rep('o1','n1'); rep('o2','n2'); rep('o3','n3');
fs.writeFileSync(F,s); console.log('account.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$TMP"; exit 1; }
rm -rf "$TMP"

node --check routes/account.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: forgot-password + change-number (re-verify) live. healthz=200"
