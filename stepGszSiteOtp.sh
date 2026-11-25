#!/usr/bin/env bash
# stepGszSiteOtp — mirror zayron.tv's WhatsApp verification onto galaxyzayron (site_otp mode): the WEBSITE sends a
# code to the customer's WhatsApp and they enter it on the site. Keeps the bot-reverse engine as the backup toggle
# (wa_verify_mode). Three edits to routes/whatsapp.js (waStatus honours customers.wa_verified; /start becomes
# mode-aware and sends the code; NEW /api/whatsapp/verification/verify endpoint) + two to views/partials/hub_model.ejs
# (the wv() modal branches to a CODE INPUT in site_otp mode; new wvCodeForm + wvNumberForm). Safe: backup, single-match
# + revert, JS pre-check of injected client code, node --check, EJS compile-check, health loop on / (==200).
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"
cp routes/whatsapp.js "$B/"; cp views/partials/hub_model.ejs "$B/"
revert(){ cp "$B/whatsapp.js" routes/whatsapp.js; cp "$B/hub_model.ejs" views/partials/hub_model.ejs; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

echo "### how lib/wanotify.js handles raw text (informational) ###"
grep -n "whatsapp.raw\|raw\|vars.body\|template_key\|function enqueue\|destination_phone" lib/wanotify.js | head -12 || true
echo "###"

# ============================ whatsapp.js W1: waStatus honours customers.wa_verified ============================
cat > "$T/w1_o" <<'O'
  async function waStatus(customerId) {
    const r = (await pool.query(
      `SELECT i.id, i.current_phone_e164, i.current_phone_verified, l.verified_at
       FROM customer_whatsapp_links l JOIN whatsapp_identities i ON i.id=l.whatsapp_identity_id
       WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1`, [customerId])).rows[0];
    return r ? { verified: true, identityId: r.id, phone: r.current_phone_e164 || '', phoneVerified: !!r.current_phone_verified, verifiedAt: r.verified_at } : { verified: false, phone: '' };
  }
O
cat > "$T/w1_n" <<'O'
  async function waStatus(customerId) {
    const r = (await pool.query(
      `SELECT i.id, i.current_phone_e164, i.current_phone_verified, l.verified_at
       FROM customer_whatsapp_links l JOIN whatsapp_identities i ON i.id=l.whatsapp_identity_id
       WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1`, [customerId])).rows[0];
    if (r) return { verified: true, identityId: r.id, phone: r.current_phone_e164 || '', phoneVerified: !!r.current_phone_verified, verifiedAt: r.verified_at };
    try {
      const cv = (await pool.query('SELECT wa_verified, wa_number FROM customers WHERE id=$1', [customerId])).rows[0];
      if (cv && cv.wa_verified) return { verified: true, phone: cv.wa_number || '', phoneVerified: true, verifiedAt: null };
    } catch (e) {}
    return { verified: false, phone: '' };
  }
O

# ============================ whatsapp.js W2: /start becomes mode-aware (site_otp sends the code) ============================
cat > "$T/w2_o" <<'O'
    const waLink = 'https://wa.me/' + String(s.wa_verify_number).replace(/[^0-9]/g, '') + '?text=' + encodeURIComponent(text);
    res.json({ id, code, text, waLink, expiresInMin: mins });
  });
O
cat > "$T/w2_n" <<'O'
    const waLink = 'https://wa.me/' + String(s.wa_verify_number).replace(/[^0-9]/g, '') + '?text=' + encodeURIComponent(text);
    if ((s.wa_verify_mode || 'bot_reverse') === 'site_otp') {
      // Site-OTP (zayron.tv style): the website sends the code to the customer's WhatsApp; they type it back here.
      let num = '';
      try { const _c = (await pool.query('SELECT wa_number FROM customers WHERE id=$1', [cust.id])).rows[0]; if (_c && _c.wa_number) num = _c.wa_number; } catch (e) {}
      const bodyNum = String((req.body && req.body.wa_number) || '').trim();
      if (!num && bodyNum) { num = bodyNum; try { await pool.query('UPDATE customers SET wa_number=$2 WHERE id=$1', [cust.id, num]); } catch (e) {} }
      const digits = String(num).replace(/[^0-9]/g, '');
      if (!digits || digits.length < 8) {
        try { await pool.query("UPDATE whatsapp_verification_sessions SET status='EXPIRED', updated_at=now() WHERE id=$1", [id]); } catch (e) {}
        return res.json({ mode: 'site_otp', needNumber: true, message: 'Enter the WhatsApp number where we should send your code.' });
      }
      let sent = false;
      try {
        const _wn = require('../lib/wanotify')(pool);
        const brand = s.site_name || 'galaxyzayron.store';
        const NL = String.fromCharCode(10);
        const bodyTxt = ['Your ' + brand + ' verification code is: ' + code, '', 'Enter this code on the website to verify your WhatsApp. It expires in ' + mins + ' minutes.', '', 'If you did not request this, you can ignore this message.'].join(NL);
        await _wn.enqueue({ destination_phone: digits, template_key: 'whatsapp.raw', vars: { body: bodyTxt }, idempotency_key: 'waverify-' + id });
        sent = true;
      } catch (e) {}
      const masked = digits.length > 4 ? ('****' + digits.slice(-4)) : digits;
      return res.json({ mode: 'site_otp', id: id, expiresInMin: mins, sentTo: masked, sent: sent });
    }
    res.json({ id, code, text, waLink, expiresInMin: mins });
  });
O

# ============================ whatsapp.js W3: NEW /verify endpoint after /status ============================
cat > "$T/w3_o" <<'O'
    if (!r) return res.status(404).json({ status: 'NOT_FOUND' });
    res.json({ status: r.status });
  });
O
cat > "$T/w3_n" <<'O'
    if (!r) return res.status(404).json({ status: 'NOT_FOUND' });
    res.json({ status: r.status });
  });

  // ---- verify by entered code (site-OTP mode: the website sent the code, the customer types it here) ----
  router.post('/api/whatsapp/verification/verify', json, body, requireLogin, async (req, res) => {
    const cust = req.session.customer; const s = await settings();
    if ((s.wa_verify_mode || 'bot_reverse') !== 'site_otp') return res.status(400).json({ ok: false, status: 'MODE', message: 'Send the code to our WhatsApp bot to verify.' });
    const code = String((req.body && req.body.code) || '').replace(/[^0-9A-Za-z-]/g, '').toUpperCase();
    const id = parseInt((req.body && req.body.id) || 0, 10) || 0;
    if (!code) return res.json({ ok: false, status: 'BAD_CODE', message: 'Enter the code we sent to your WhatsApp.' });
    const c = await pool.connect();
    try {
      await c.query('BEGIN');
      const sess = (await c.query("SELECT * FROM whatsapp_verification_sessions WHERE customer_id=$1 AND status='PENDING' AND (id=$2 OR $2=0) ORDER BY id DESC LIMIT 1 FOR UPDATE", [cust.id, id])).rows[0];
      if (!sess) { await c.query('ROLLBACK'); return res.json({ ok: false, status: 'NO_SESSION', message: 'This code has expired. Please request a new one.' }); }
      if (new Date(sess.expires_at) < new Date()) {
        await c.query("UPDATE whatsapp_verification_sessions SET status='EXPIRED', updated_at=now() WHERE id=$1", [sess.id]);
        await c.query('COMMIT');
        return res.json({ ok: false, status: 'EXPIRED', message: 'This code has expired. Please request a new one.' });
      }
      if (String(sess.display_code).toUpperCase() !== code) {
        await c.query('COMMIT');
        return res.json({ ok: false, status: 'BAD_CODE', message: 'That code did not match. Please check and try again.' });
      }
      let num = '';
      try { const _c = (await c.query('SELECT wa_number FROM customers WHERE id=$1', [cust.id])).rows[0]; if (_c && _c.wa_number) num = _c.wa_number; } catch (e) {}
      let identity = null;
      try {
        const e164 = (waid.normalizePhoneE164 ? waid.normalizePhoneE164(num) : null) || ('+' + String(num).replace(/[^0-9]/g, ''));
        const rr = await waid.resolveOrCreateIdentity(c, { phone: e164 }, { phoneVerified: true });
        identity = rr && rr.identity;
      } catch (e) { identity = null; }
      if (identity) {
        const other = (await c.query("SELECT customer_id FROM customer_whatsapp_links WHERE whatsapp_identity_id=$1 AND status='ACTIVE' LIMIT 1", [identity.id])).rows[0];
        if (other && other.customer_id !== cust.id) {
          await c.query("UPDATE whatsapp_verification_sessions SET status='FAILED', whatsapp_identity_id=$2, updated_at=now() WHERE id=$1", [sess.id, identity.id]);
          await c.query('COMMIT');
          await audit('WHATSAPP_VERIFICATION_FAILED', { customer_id: cust.id, identity_id: identity.id, reason: 'IDENTITY_ALREADY_LINKED' });
          return res.json({ ok: false, status: 'FAILED', message: 'This WhatsApp is already linked to another account.' });
        }
        const existing = (await c.query("SELECT whatsapp_identity_id FROM customer_whatsapp_links WHERE customer_id=$1 AND status='ACTIVE' AND is_primary=true LIMIT 1", [cust.id])).rows[0];
        if (!existing) {
          await c.query("INSERT INTO customer_whatsapp_links(customer_id,whatsapp_identity_id,is_primary,status,verified_at,link_reason) VALUES($1,$2,true,'ACTIVE',now(),'SITE_OTP_VERIFICATION')", [cust.id, identity.id]);
        }
        await c.query('UPDATE whatsapp_verification_sessions SET whatsapp_identity_id=$2 WHERE id=$1', [sess.id, identity.id]);
      }
      await c.query('UPDATE customers SET wa_verified=true WHERE id=$1', [cust.id]);
      await c.query("UPDATE whatsapp_verification_sessions SET status='VERIFIED', completed_at=now(), updated_at=now() WHERE id=$1", [sess.id]);
      await c.query('COMMIT');
      await audit('WHATSAPP_VERIFICATION_COMPLETED', { customer_id: cust.id, identity_id: identity ? identity.id : null, reason: 'SITE_OTP' });
      return res.json({ ok: true, status: 'VERIFIED' });
    } catch (e) {
      try { await c.query('ROLLBACK'); } catch (_e) {}
      return res.json({ ok: false, status: 'ERROR', message: 'Could not verify right now. Please try again.' });
    } finally { c.release(); }
  });
O

# ============================ hub_model.ejs H1: wv() start-response branches on mode ============================
cat > "$T/h1_o" <<'O'
        if(o.s!==200||!j.id){ wvFail(back, j.message||'WhatsApp verification isn’t available right now.'); return; }
        wvRender(j,back);
O
cat > "$T/h1_n" <<'O'
        if(o.s!==200){ wvFail(back, j.message||'WhatsApp verification isn’t available right now.'); return; }
        if(j.mode==='site_otp'){ if(j.needNumber){ wvNumberForm(back); return; } wvCodeForm(j,back); return; }
        if(!j.id){ wvFail(back, j.message||'WhatsApp verification isn’t available right now.'); return; }
        wvRender(j,back);
O

# ============================ hub_model.ejs H2: add wvCodeForm + wvNumberForm before wvSuccess ============================
cat > "$T/h2_o" <<'O'
  function wvSuccess(back){ wvStop();
O
cat > "$T/h2_n" <<'O'
  function wvCodeForm(j,back){
    var sent=(j.sent!==false);
    body.innerHTML='<button class="cthm-back" id="wvBack">← Back</button>'
      +'<div style="text-align:center;margin:0 0 10px"><div style="font-weight:800;font-size:16px">Verify your WhatsApp</div><p class="muted" style="margin:4px 0 0">'+(sent?('We sent a code to your WhatsApp'+(j.sentTo?(' '+esc(j.sentTo)):'')+'. Enter it below to verify.'):'We couldn’t send your code just now — tap Resend to try again.')+'</p></div>'
      +'<input id="wvInput" inputmode="numeric" autocomplete="one-time-code" maxlength="8" placeholder="Enter code" style="width:100%;box-sizing:border-box;padding:13px 14px;border:1px solid #e3e3ea;border-radius:12px;background:#fff;color:#111;text-align:center;letter-spacing:6px;font-size:22px;font-weight:800;font-family:inherit" />'
      +'<div class="muted errmsg" id="wvErr" style="display:none;margin:8px 0 0;text-align:center"></div>'
      +'<button class="cbtn cbtn-p" id="wvSubmit" style="width:100%;margin-top:10px">Verify</button>'
      +'<div style="text-align:center;margin-top:10px"><button class="cthm-back" id="wvResend" style="padding:0;font-size:13px">Resend code</button></div>';
    var bk=document.getElementById('wvBack'); if(bk) bk.addEventListener('click',function(){ (back||account)(); });
    var inp=document.getElementById('wvInput'); if(inp){ try{inp.focus();}catch(e){} }
    var er=document.getElementById('wvErr');
    function showErr(m){ if(er){ er.textContent=m; er.style.display='block'; } }
    function submit(){
      var code=((inp&&inp.value)||'').replace(/[^0-9A-Za-z-]/g,''); if(!code){ showErr('Enter the code we sent you.'); return; }
      var sb=document.getElementById('wvSubmit'); if(sb){ sb.disabled=true; sb.textContent='Verifying…'; }
      fetch('/api/whatsapp/verification/verify',{method:'POST',headers:{'Content-Type':'application/json','X-Requested-With':'fetch'},credentials:'same-origin',body:JSON.stringify({id:j.id,code:code})})
        .then(function(r){ return r.json(); }).then(function(v){
          if(v&&v.ok){ wvSuccess(back); return; }
          if(sb){ sb.disabled=false; sb.textContent='Verify'; }
          showErr((v&&v.message)||'That code didn’t match. Please try again.');
        }).catch(function(){ if(sb){ sb.disabled=false; sb.textContent='Verify'; } showErr('Couldn’t verify right now. Please try again.'); });
    }
    var sbt=document.getElementById('wvSubmit'); if(sbt) sbt.addEventListener('click',submit);
    if(inp) inp.addEventListener('keydown',function(e){ if(e.key==='Enter'){ e.preventDefault(); submit(); } });
    var rs=document.getElementById('wvResend'); if(rs) rs.addEventListener('click',function(){ waVerify(back); });
  }
  function wvNumberForm(back){
    body.innerHTML='<button class="cthm-back" id="wvBack">← Back</button>'
      +'<div style="text-align:center;margin:0 0 10px"><div style="font-weight:800;font-size:16px">Verify your WhatsApp</div><p class="muted" style="margin:4px 0 0">Enter your WhatsApp number with country code and we’ll send you a code.</p></div>'
      +'<input id="wvNumIn" inputmode="tel" autocomplete="tel" placeholder="e.g. 923001234567" style="width:100%;box-sizing:border-box;padding:13px 14px;border:1px solid #e3e3ea;border-radius:12px;background:#fff;color:#111;text-align:center;font-size:17px;font-weight:700;font-family:inherit" />'
      +'<div class="muted errmsg" id="wvErr" style="display:none;margin:8px 0 0;text-align:center"></div>'
      +'<button class="cbtn cbtn-p" id="wvSend" style="width:100%;margin-top:10px">Send code</button>';
    var bk=document.getElementById('wvBack'); if(bk) bk.addEventListener('click',function(){ (back||account)(); });
    var inp=document.getElementById('wvNumIn'); if(inp){ try{inp.focus();}catch(e){} }
    var er=document.getElementById('wvErr');
    function showErr(m){ if(er){ er.textContent=m; er.style.display='block'; } }
    function send(){
      var num=((inp&&inp.value)||'').replace(/[^0-9]/g,''); if(num.length<8){ showErr('Enter a valid WhatsApp number with country code.'); return; }
      var sb=document.getElementById('wvSend'); if(sb){ sb.disabled=true; sb.textContent='Sending…'; }
      fetch('/api/whatsapp/verification/start',{method:'POST',headers:{'Content-Type':'application/json','X-Requested-With':'fetch'},credentials:'same-origin',body:JSON.stringify({wa_number:num})})
        .then(function(r){ return r.json().then(function(j){ return {s:r.status,j:j||{}}; }).catch(function(){ return {s:r.status,j:{}}; }); })
        .then(function(o){ var j=o.j;
          if(j.already){ wvSuccess(back); return; }
          if(j.mode==='site_otp'&&j.id){ wvCodeForm(j,back); return; }
          if(sb){ sb.disabled=false; sb.textContent='Send code'; }
          showErr((j&&j.message)||'Couldn’t send the code. Please try again.');
        }).catch(function(){ if(sb){ sb.disabled=false; sb.textContent='Send code'; } showErr('Couldn’t send the code. Please try again.'); });
    }
    var sbn=document.getElementById('wvSend'); if(sbn) sbn.addEventListener('click',send);
    if(inp) inp.addEventListener('keydown',function(e){ if(e.key==='Enter'){ e.preventDefault(); send(); } });
  }
  function wvSuccess(back){ wvStop();
O

# ---- JS pre-check of the injected CLIENT code (syntax only; undefined refs are fine for --check) ----
{
  echo 'var body,esc,account,waVerify,wvStop,wvSuccess,wvFail,wvRender,wvNumberForm,wvCodeForm;'
  # the two new functions, minus the trailing wvSuccess opener line
  sed '$d' "$T/h2_n"
  echo 'function wvSuccess(){}'
  echo 'function _branch(o){ var j=o.j, back;'
  cat "$T/h1_n"
  echo '}'
} > "$T/chk.js"
node --check "$T/chk.js" || { echo "INJECTED CLIENT JS HAS A SYNTAX ERROR - aborting, nothing changed"; rm -rf "$T"; exit 1; }
echo "injected client JS syntax OK"

# ---- apply all anchors (single-match + abort/revert on any miss) ----
node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' matched x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('routes/whatsapp.js', [['w1_o','w1_n'],['w2_o','w2_n'],['w3_o','w3_n']]);
patch('views/partials/hub_model.ejs', [['h1_o','h1_n'],['h2_o','h2_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/whatsapp.js || { echo "whatsapp.js syntax error - reverting"; revert; exit 1; }
node -e "require('ejs').compile(require('fs').readFileSync('views/partials/hub_model.ejs','utf8'),{filename:'views/partials/hub_model.ejs'})" || { echo "hub_model.ejs EJS compile error - reverting"; revert; exit 1; }

pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }
echo "DONE: site-OTP verification live behind the wa_verify_mode toggle. ON = website sends code → customer enters it; OFF = bot-reverse backup. gsz http=${HC}"
