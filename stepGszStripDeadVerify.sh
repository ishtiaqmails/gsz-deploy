#!/usr/bin/env bash
# stepGszStripDeadVerify — remove the now-dead legacy WhatsApp-verify code (site_otp is fully handled by the Hub
# modal + /api/whatsapp/verification/{start,verify}). Deletes from routes/account.js: the WHATSAPP VERIFICATION
# comment, waVerifyMode(), sendWaCode(), and the three /account/verify-whatsapp routes (GET + POST + resend); and
# retires views/account/verify_whatsapp.ejs (moved to the backup dir, recoverable). Nothing else references them
# (verified repo-wide). Safe: backup, single-match + revert, node --check, health loop on / (==200).
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"
cp routes/account.js "$B/"
[ -f views/account/verify_whatsapp.ejs ] && cp views/account/verify_whatsapp.ejs "$B/"
revert(){ cp "$B/account.js" routes/account.js; [ -f "$B/verify_whatsapp.ejs" ] && cp "$B/verify_whatsapp.ejs" views/account/verify_whatsapp.ejs; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/o" <<'O'
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
    return res.redirect('/account');
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

  // ---- DASHBOARD (Phase 1: profile + verification; orders/trials come in Phase 3) ----
O
cat > "$T/n" <<'O'
  // ---- DASHBOARD (Phase 1: profile + verification; orders/trials come in Phase 3) ----
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('routes/account.js','utf8'); const O=rd('o'),N=rd('n');
const c=s.split(O).length-1; if(c!==1){ console.error('ANCHOR matched x'+c+' - aborting'); process.exit(5); }
s=s.split(O).join(N); fs.writeFileSync('routes/account.js',s); console.log('routes/account.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/account.js || { echo "syntax error - reverting"; revert; exit 1; }

# retire the view (moved to backup, not hard-deleted)
if [ -f views/account/verify_whatsapp.ejs ]; then mv views/account/verify_whatsapp.ejs "$B/verify_whatsapp.ejs.removed"; echo "retired views/account/verify_whatsapp.ejs -> $B/"; fi

# belt-and-braces: no dead references should remain
LEFT=$(grep -rn "verify-whatsapp\|verify_whatsapp\|sendWaCode\|waVerifyMode" --include=*.js --include=*.ejs routes views 2>/dev/null | grep -v node_modules | grep -v "/\.retired/" | wc -l)
echo "remaining dead references: ${LEFT}"

pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }
echo "DONE: legacy WhatsApp-verify code removed (${LEFT} refs left). Site-OTP runs solely on the Hub + /start + /verify. gsz http=${HC}"
