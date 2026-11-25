#!/usr/bin/env bash
# stepGszVerifyMirror1 — verification mirror #1 (backend). Adds the zayron.tv-style site-OTP WhatsApp verify
# for galaxyzayron, GATED behind wa_settings.wa_verify_mode (default 'bot_reverse' = current behavior, so this
# deploy is a no-op until you flip the toggle in step 2). Adds: wa verify routes + helpers + view, signup
# trigger, and makes the trial gate accept wa_verified. Email verification untouched.
# Edits routes/account.js (3 anchors) + new view + 1 settings row. Safe: backup, single-match + auto-revert, node --check, health loop.
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp routes/account.js "$B/account.js.bak"
[ -f views/account/verify_whatsapp.ejs ] && cp views/account/verify_whatsapp.ejs "$B/" || true
revert(){ cp "$B/account.js.bak" routes/account.js; rm -f views/account/verify_whatsapp.ejs; [ -f "$B/verify_whatsapp.ejs" ] && cp "$B/verify_whatsapp.ejs" views/account/ || true; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# ---- the new verify-whatsapp view (mirrors verify_email.ejs) ----
cat > views/account/verify_whatsapp.ejs <<'EJS'
<%- include('../partials/store_top') %>
<%- include('../partials/auth_style') %>
<main class="auth">
  <div class="wrap" style="display:flex;justify-content:center">
    <div class="auth-card">
      <span class="auth-badge"><span class="dot"></span>One quick step</span>
      <h1>Verify your WhatsApp</h1>
      <p class="lead">We sent a 6-digit code to your WhatsApp<% if (typeof wa !== 'undefined' && wa) { %> (+<%= wa %>)<% } %>. Enter it below to verify your number.</p>
      <% if (sent) { %><div class="okmsg">A fresh code is on its way — check your WhatsApp.</div><% } %>
      <% if (error) { %><div class="err"><%= error %></div><% } %>
      <form method="post" action="/account/verify-whatsapp">
        <label class="fld" for="code">Verification code</label>
        <input id="code" class="code-in" type="text" name="code" inputmode="numeric" maxlength="6" placeholder="000000" autocomplete="one-time-code" required>
        <button class="btn btn-p btn-full" type="submit">Verify WhatsApp</button>
      </form>
      <div class="linkrow">
        <form method="post" action="/account/verify-whatsapp/resend" style="margin:0"><button class="ghostbtn" type="submit">Resend code</button></form>
        <a class="ghostbtn" href="/account" style="text-decoration:none">Skip for now →</a>
      </div>
    </div>
  </div>
</main>
<%- include('../partials/store_bottom') %>
EJS

# ---- account.js anchors ----
cat > "$T/a_o" <<'O'
      const c = r.rows[0];
      req.session.customer = slim(c);
      /* no verification sent on signup — email code sends only when the customer clicks Verify email; WhatsApp via bot */
      if (ajax) return res.json({ ok:true, redirect: '/account' }); /*noEmailVerify*/
      res.redirect('/account');
O
cat > "$T/a_n" <<'O'
      const c = r.rows[0];
      req.session.customer = slim(c);
      /* WhatsApp verify: site_otp -> send a code and take them to the verify page; bot_reverse -> current (via bot) */
      let _waNext = '/account';
      try { if ((await waVerifyMode()) === 'site_otp' && c.wa_number) { await sendWaCode(c); _waNext = '/account/verify-whatsapp'; } } catch (e) {}
      if (ajax) return res.json({ ok:true, redirect: _waNext });
      res.redirect(_waNext);
O

cat > "$T/b_o" <<'O'
  async function _ivWaVerified(c){ try{ const r=await pool.query("SELECT 1 FROM customer_whatsapp_links l WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1",[c.id]); return r.rows.length>0; }catch(e){ return false; } }
O
cat > "$T/b_n" <<'O'
  async function _ivWaVerified(c){ try{ const r=await pool.query("SELECT (cu.wa_verified OR EXISTS(SELECT 1 FROM customer_whatsapp_links l WHERE l.customer_id=cu.id AND l.status='ACTIVE' AND l.is_primary=true)) AS ok FROM customers cu WHERE cu.id=$1",[c.id]); return !!(r.rows[0] && r.rows[0].ok); }catch(e){ return false; } }
O

cat > "$T/c_o" <<'O'
  router.post('/account/verify-email/resend', requireLogin, async (req, res) => {
    const c = req.session.customer;
    try { const full = (await pool.query('SELECT * FROM customers WHERE id=$1', [c.id])).rows[0]; if (full && !full.email_verified) await sendEmailCode(full); } catch (e) {}
    res.redirect('/account/verify-email?sent=1');
  });
O
cat > "$T/c_n" <<'O'
  router.post('/account/verify-email/resend', requireLogin, async (req, res) => {
    const c = req.session.customer;
    try { const full = (await pool.query('SELECT * FROM customers WHERE id=$1', [c.id])).rows[0]; if (full && !full.email_verified) await sendEmailCode(full); } catch (e) {}
    res.redirect('/account/verify-email?sent=1');
  });

  // ---- WHATSAPP VERIFICATION (site_otp mode — mirrors zayron.tv: the site sends a code, customer enters it here) ----
  async function waVerifyMode(){ try{ const r=await pool.query("SELECT value FROM wa_settings WHERE key='wa_verify_mode'"); return (r.rows[0] && String(r.rows[0].value)==='site_otp') ? 'site_otp' : 'bot_reverse'; }catch(e){ return 'bot_reverse'; } }
  async function sendWaCode(cust){
    try{
      const id = cust.id; const wa = String(cust.wa_number||'').replace(/[^0-9]/g,''); if(!wa) return;
      const code = String(Math.floor(100000 + Math.random()*900000));
      await pool.query("INSERT INTO customer_tokens(customer_id, kind, code, expires_at) VALUES($1,'wa_verify',$2, now() + interval '10 minutes')", [id, code]);
      const site = (((await pool.query("SELECT value FROM wa_settings WHERE key='site_base_url'")).rows[0])||{}).value || 'galaxyzayron.store';
      const host = String(site).replace(/^https?:\/\//,'').replace(/\/+$/,'');
      const bodyTxt = 'Your ' + host + ' verification code is ' + code + '\n\nEnter it on the website to verify your WhatsApp. It expires in 10 minutes.';
      await wanotify.enqueue({ customer_id:id, destination_phone:wa, template_key:'whatsapp.raw', vars:{ body:bodyTxt }, idempotency_key:'waverify-'+id+'-'+code });
    }catch(e){}
  }
  router.get('/account/verify-whatsapp', requireLogin, async (req, res) => {
    const c = req.session.customer;
    try{ const full=(await pool.query('SELECT wa_verified FROM customers WHERE id=$1',[c.id])).rows[0]; if(full && full.wa_verified) return res.redirect('/account'); }catch(e){}
    res.render('account/verify_whatsapp', Object.assign(await shell(), { title:'Verify your WhatsApp', error:null, sent:req.query.sent==='1', wa:(c.wa_number||'') }));
  });
  router.post('/account/verify-whatsapp', body, requireLogin, async (req, res) => {
    const c = req.session.customer;
    const code = String(req.body.code || '').replace(/[^0-9]/g, '');
    const re = (err) => shell().then(s => res.render('account/verify_whatsapp', Object.assign(s, { title:'Verify your WhatsApp', error:err, sent:false, wa:(c.wa_number||'') })));
    if (code.length !== 6) return re('Enter the 6-digit code we sent to your WhatsApp.');
    try {
      const t = (await pool.query("SELECT * FROM customer_tokens WHERE customer_id=$1 AND kind='wa_verify' AND used=false AND expires_at > now() ORDER BY id DESC LIMIT 1", [c.id])).rows[0];
      if (!t) return re('That code has expired. Tap "Resend code" for a new one.');
      if (t.tries >= 6) return re('Too many attempts. Tap "Resend code" for a fresh code.');
      if (String(t.code) !== code) { await pool.query('UPDATE customer_tokens SET tries = tries + 1 WHERE id=$1', [t.id]); return re('That code is not correct. Please check and try again.'); }
      await pool.query('UPDATE customer_tokens SET used=true WHERE id=$1', [t.id]);
      await pool.query('UPDATE customers SET wa_verified=true WHERE id=$1', [c.id]);
      req.session.customer.wa_verified = true;
      res.redirect('/account?ok=wa');
    } catch (e) { re('Something went wrong. Please try again.'); }
  });
  router.post('/account/verify-whatsapp/resend', requireLogin, async (req, res) => {
    const c = req.session.customer;
    try { const full = (await pool.query('SELECT * FROM customers WHERE id=$1', [c.id])).rows[0]; if (full && !full.wa_verified) await sendWaCode(full); } catch (e) {}
    res.redirect('/account/verify-whatsapp?sent=1');
  });
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('routes/account.js', [['a_o','a_n'],['b_o','b_n'],['c_o','c_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

# ---- ensure the toggle setting exists (default bot_reverse = no behavior change) ----
node - <<'NODE'
const {Pool}=require("pg");const fs=require("fs");
const env={};try{fs.readFileSync(".env","utf8").split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/);if(m)env[m[1]]=m[2].replace(/^["']|["']$/g,"").trim();});}catch(e){}
const p=new Pool({host:env.DB_HOST||"127.0.0.1",port:+(env.DB_PORT||5432),user:env.DB_USER,password:env.DB_PASS||env.DB_PASSWORD,database:env.DB_NAME});
(async()=>{try{ await p.query("INSERT INTO wa_settings(key,value) VALUES('wa_verify_mode','bot_reverse') ON CONFLICT(key) DO NOTHING"); const r=(await p.query("SELECT value FROM wa_settings WHERE key='wa_verify_mode'")).rows[0]; console.log('wa_verify_mode =', r && r.value); }catch(e){console.log('settings err:',e.message)} process.exit(0);})();
NODE

node --check routes/account.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }
echo "DONE: site-OTP WhatsApp verify built + gated (mode=bot_reverse, no behavior change). Flip to site_otp in step 2 to activate. gsz http=${HC}"
