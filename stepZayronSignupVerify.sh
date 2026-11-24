#!/usr/bin/env bash
# stepZayronSignupVerify — wire a WhatsApp verification step into signup (delivered via the
# Verification Bot through otp_outbox). GATED by signup_otp_on: deployed OFF, so live signup is
# UNCHANGED until you flip signup_otp_on=1. When on: signup -> code on WhatsApp -> /account/verify
# -> phone_verified=true -> logged in. Adds customers.otp_code/otp_expires. Safe: backup+anchors+check.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zsv; rm -rf "$W"; mkdir -p "$W/p"
cp routes/account.js "$W/account.js.bak"
revert(){ cp "$W/account.js.bak" routes/account.js; }

# ---- 1) signup POST: branch to WhatsApp verify when otpOn() ----
cat > "$W/p/o1" <<'OLD'
      const cust = r.rows[0];
      req.session.customer = { id: cust.id, phone: cust.phone, name: cust.name };
      await pool.query('UPDATE customers SET last_login_at=now(), last_country=COALESCE($2, last_country) WHERE id=$1', [cust.id, geoOf(req).cc]);
      if (wantsJson(req)) return res.json({ ok:true, next: b.next || '/account' });
      return res.redirect(b.next || '/account');
OLD
cat > "$W/p/n1" <<'NEW'
      const cust = r.rows[0];
      // WhatsApp verification — when enabled, confirm the number before the account is usable
      if ((await otpOn()) && phone) {
        const code = String(Math.floor(100000 + Math.random() * 900000));
        await pool.query("UPDATE customers SET otp_code=$1, otp_expires=now() + interval '10 minutes', phone_verified=false WHERE id=$2", [code, cust.id]);
        await pool.query("INSERT INTO otp_outbox (phone, body, status) VALUES ($1,$2,'queued')", [phone, 'Your Zayron verification code is: ' + code + '. It expires in 10 minutes.']);
        req.session.pending = { id: cust.id, phone: cust.phone, name: cust.name, next: b.next || '/account' };
        if (wantsJson(req)) return res.json({ ok:true, verify:true, next: '/account/verify' });
        return res.redirect('/account/verify');
      }
      req.session.customer = { id: cust.id, phone: cust.phone, name: cust.name };
      await pool.query('UPDATE customers SET last_login_at=now(), last_country=COALESCE($2, last_country) WHERE id=$1', [cust.id, geoOf(req).cc]);
      if (wantsJson(req)) return res.json({ ok:true, next: b.next || '/account' });
      return res.redirect(b.next || '/account');
NEW

# ---- 2) verify routes + form, inserted before the LOGIN section ----
cat > "$W/p/o2" <<'OLD'
  // ---------- LOGIN ----------
OLD
cat > "$W/p/n2" <<'NEW'
  // ---------- WHATSAPP VERIFICATION (signup) ----------
  function verifyForm(v) {
    v = v || {};
    return `
<form method="post" action="/account/verify" autocomplete="one-time-code">
  <p class="acc-sub" style="margin:0 0 12px">We sent a 6-digit code on WhatsApp to <b>${esc(v.phone || 'your number')}</b>. Enter it below to finish.</p>
  <div class="acc-f"><label>Verification code</label>
    <input name="code" inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="123456" style="letter-spacing:4px;font-size:18px"></div>
  <button class="acc-go" type="submit">Verify &amp; continue</button>
</form>
<form method="post" action="/account/verify/resend" style="margin-top:10px">
  <button type="submit" style="background:none;border:0;color:#0047FF;cursor:pointer;padding:0;font:inherit">Resend code</button>
</form>`;
  }
  async function renderVerify(req, res, error) {
    const p = req.session.pending;
    if (!p) return res.redirect('/account/signup');
    return res.send(shellPage('Verify your number — Zayron', authPage({
      kicker: 'Verify', title: 'Confirm your WhatsApp',
      sub: 'One quick step to secure your account.',
      error, body: verifyForm({ phone: p.phone })
    }), await deps.getPublicData(), { noindex: true }));
  }
  router.get('/verify', async (req, res) => {
    if (me(req)) return res.redirect('/account');
    return renderVerify(req, res, '');
  });
  router.post('/verify', body, async (req, res) => {
    const p = req.session.pending;
    if (!p) return wantsJson(req) ? res.json({ ok:false, error:'expired' }) : res.redirect('/account/signup');
    const code = String((req.body && req.body.code) || '').replace(/[^0-9]/g, '');
    try {
      const r = await pool.query('SELECT otp_code, otp_expires FROM customers WHERE id=$1', [p.id]);
      const row = r.rows[0];
      if (!row || !row.otp_code || (row.otp_expires && new Date(row.otp_expires) < new Date())) {
        return wantsJson(req) ? res.json({ ok:false, error:'expired' }) : renderVerify(req, res, 'That code has expired. Tap "Resend code".');
      }
      if (code !== row.otp_code) {
        return wantsJson(req) ? res.json({ ok:false, error:'badcode' }) : renderVerify(req, res, 'That code is not right. Please try again.');
      }
      await pool.query('UPDATE customers SET phone_verified=true, otp_code=null, otp_expires=null, last_login_at=now() WHERE id=$1', [p.id]);
      req.session.customer = { id: p.id, phone: p.phone, name: p.name };
      const next = p.next || '/account';
      delete req.session.pending;
      return wantsJson(req) ? res.json({ ok:true, next }) : res.redirect(next);
    } catch (e) {
      return wantsJson(req) ? res.json({ ok:false, error:'error' }) : renderVerify(req, res, 'Something went wrong. Please try again.');
    }
  });
  router.post('/verify/resend', async (req, res) => {
    const p = req.session.pending;
    if (!p) return res.redirect('/account/signup');
    try {
      const code = String(Math.floor(100000 + Math.random() * 900000));
      await pool.query("UPDATE customers SET otp_code=$1, otp_expires=now() + interval '10 minutes' WHERE id=$2", [code, p.id]);
      await pool.query("INSERT INTO otp_outbox (phone, body, status) VALUES ($1,$2,'queued')", [p.phone, 'Your Zayron verification code is: ' + code + '. It expires in 10 minutes.']);
    } catch (e) {}
    return renderVerify(req, res, 'A new code is on its way.');
  });

  // ---------- LOGIN ----------
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zsv/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+']'); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('routes/account.js','o1','n1');
rep('routes/account.js','o2','n2');
console.log('account.js PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
node --check routes/account.js || { echo "syntax error - reverting"; revert; exit 1; }

# columns for the signup code
node -e "const{pool}=require('./db');pool.query('ALTER TABLE customers ADD COLUMN IF NOT EXISTS otp_code text, ADD COLUMN IF NOT EXISTS otp_expires timestamptz').then(()=>{console.log('customers.otp_code/otp_expires ready');process.exit(0)}).catch(e=>{console.log('ALTER err',e.message);process.exit(1)})"

pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
echo "DONE: signup WhatsApp verification wired (gated by signup_otp_on, currently OFF — live signup unchanged until you enable it)."
