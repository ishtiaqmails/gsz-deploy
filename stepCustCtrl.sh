#!/usr/bin/env bash
# stepCustCtrl.sh — admin customer account control: change email / phone, set password, reset password.
# Routes hash with the login's exact scrypt scheme; stored password is never shown. UI in the view modal.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F1=routes/adminCustomers.js
F2=views/admin/customers.ejs
cp -f "$F1" "$F1.xbak.$TS"; cp -f "$F2" "$F2.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F1.xbak.$TS" "$F1"; cp -f "$F2.xbak.$TS" "$F2"; rm -f .gszm_p.js .gszm_v.js; exit 1; }
trap restore ERR

echo "==> adding routes + modal controls"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
function patch(file, a, b, label) {
  let s = fs.readFileSync(file, 'utf8');
  const n = s.split(a).length - 1;
  if (n !== 1) throw new Error(file + ' ' + label + ': anchor x' + n + ' (need 1)');
  fs.writeFileSync(file, s.split(a).join(b));
  console.log('  ' + label + ': ok');
}
if (fs.readFileSync('routes/adminCustomers.js', 'utf8').indexOf('reset-password') >= 0) { console.log('  already patched'); process.exit(0); }

patch('routes/adminCustomers.js',
  `  const router = express.Router();`,
  `  const router = express.Router();
  const crypto = require('crypto');
  function hashPw(pw){ const salt=crypto.randomBytes(16); const dk=crypto.scryptSync(String(pw),salt,64); return 's1$'+salt.toString('hex')+'$'+dk.toString('hex'); }
  function genPw(){ const ch='ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'; const b=crypto.randomBytes(12); let s=''; for(let i=0;i<12;i++) s+=ch[b[i]%ch.length]; return s; }`,
  'crypto + hash');

patch('routes/adminCustomers.js', `  return router;`,
`  router.post('/customers/:id/email', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const em = String((req.body && req.body.email) || '').trim().toLowerCase();
    if (!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(em)) return res.json({ ok:false, error:'Enter a valid email address.' });
    try {
      const dup = (await pool.query('SELECT id FROM customers WHERE lower(email)=lower($1) AND id<>$2 LIMIT 1', [em, id])).rows[0];
      if (dup) return res.json({ ok:false, error:'That email is already in use.' });
      await pool.query('UPDATE customers SET email=$1, email_verified=false WHERE id=$2', [em, id]);
      return res.json({ ok:true, email:em });
    } catch (e) { return res.json({ ok:false, error:'Could not update the email.' }); }
  });
  router.post('/customers/:id/phone', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const d = String((req.body && req.body.phone) || '').replace(/[^0-9]/g, '');
    if (d.length < 8) return res.json({ ok:false, error:'Enter a valid number with country code.' });
    try {
      await pool.query('UPDATE customers SET wa_number=$1, wa_verified=false WHERE id=$2', [d, id]);
      try { await pool.query("UPDATE customer_whatsapp_links SET status='UNLINKED', is_primary=false, unlinked_at=now(), updated_at=now() WHERE customer_id=$1 AND status='ACTIVE'", [id]); } catch (e) {}
      return res.json({ ok:true, phone:d });
    } catch (e) { return res.json({ ok:false, error:'Could not update the number.' }); }
  });
  router.post('/customers/:id/set-password', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const pw = String((req.body && req.body.password) || '');
    if (pw.length < 6) return res.json({ ok:false, error:'Password must be at least 6 characters.' });
    try { await pool.query('UPDATE customers SET pass_hash=$1 WHERE id=$2', [hashPw(pw), id]); return res.json({ ok:true }); }
    catch (e) { return res.json({ ok:false, error:'Could not set the password.' }); }
  });
  router.post('/customers/:id/reset-password', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const pw = genPw();
    try { await pool.query('UPDATE customers SET pass_hash=$1 WHERE id=$2', [hashPw(pw), id]); return res.json({ ok:true, password:pw }); }
    catch (e) { return res.json({ ok:false, error:'Could not reset the password.' }); }
  });

  return router;`, 'routes');

// ---- customers.ejs ----
patch('views/admin/customers.ejs', `<!-- View modal -->`,
`<style>
.cu-ctrl{margin-top:16px;border-top:1px solid var(--hair);padding-top:14px}
.cu-ctrl .cu-oh{margin-bottom:10px}
.cu-crow{display:flex;gap:8px;margin-bottom:9px;flex-wrap:wrap;align-items:center}
.cu-crow input{flex:1;min-width:150px;border:1px solid var(--hair);border-radius:9px;padding:9px 11px;font:inherit;background:#fff}
.cu-crow .btn{flex:none}
.cu-msg{font-size:13px;font-weight:600;margin:8px 0 0;word-break:break-word;line-height:1.5}
</style>
<!-- View modal -->`, 'modal css');

patch('views/admin/customers.ejs', `  window.cuView=function(id){`,
`  function cuMsg(t,ok){ var m=document.getElementById('cuMsg'); if(m){ m.textContent=t; m.style.color=ok?'#0b7a42':'#b42318'; } }
  function cuPost(url,data,cb){ fetch(url,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams(data),credentials:'same-origin'}).then(function(r){return r.json();}).then(cb).catch(function(){ cuMsg('Network error — please try again.',false); }); }
  window.cuSetEmail=function(id){ cuPost('/admin/customers/'+id+'/email',{email:(document.getElementById('cuEmail')||{}).value||''},function(d){ cuMsg(d&&d.ok?'Email updated — marked unverified.':((d&&d.error)||'Error'),!!(d&&d.ok)); }); };
  window.cuSetPhone=function(id){ cuPost('/admin/customers/'+id+'/phone',{phone:(document.getElementById('cuPhone')||{}).value||''},function(d){ cuMsg(d&&d.ok?'WhatsApp number updated — marked unverified.':((d&&d.error)||'Error'),!!(d&&d.ok)); }); };
  window.cuSetPw=function(id){ var el=document.getElementById('cuPw'); cuPost('/admin/customers/'+id+'/set-password',{password:(el||{}).value||''},function(d){ if(d&&d.ok){ cuMsg('Password set.',true); if(el) el.value=''; } else cuMsg((d&&d.error)||'Error',false); }); };
  window.cuResetPw=function(id){ if(!confirm('Reset this customer to a new generated password?')) return; cuPost('/admin/customers/'+id+'/reset-password',{},function(d){ if(d&&d.ok){ cuMsg('New password: '+d.password+'   — copy and share with the customer (shown once).',true); } else cuMsg((d&&d.error)||'Error',false); }); };
  window.cuView=function(id){`, 'modal helpers');

patch('views/admin/customers.ejs', `      body.innerHTML=kv+oh+ob;`,
`      var ctrl='<div class="cu-ctrl"><div class="cu-oh">Account controls</div>'
        +'<div class="cu-crow"><input id="cuEmail" type="text" value="'+esc(c.email||'')+'" placeholder="Email address"><button class="btn btn-g" type="button" onclick="cuSetEmail('+c.id+')">Save email</button></div>'
        +'<div class="cu-crow"><input id="cuPhone" type="text" value="'+esc(c.wa_number||'')+'" placeholder="WhatsApp number"><button class="btn btn-g" type="button" onclick="cuSetPhone('+c.id+')">Save number</button></div>'
        +'<div class="cu-crow"><input id="cuPw" type="text" placeholder="New password (min 6)"><button class="btn btn-g" type="button" onclick="cuSetPw('+c.id+')">Set password</button></div>'
        +'<div class="cu-crow"><button class="btn btn-p" type="button" style="width:100%;justify-content:center" onclick="cuResetPw('+c.id+')">Reset password — generate a new one</button></div>'
        +'<p class="cu-msg" id="cuMsg"></p></div>';
      body.innerHTML=kv+oh+ob+ctrl;`, 'modal controls');
JS
node .gszm_p.js

echo "==> validating"
node --check routes/adminCustomers.js
cat > .gszm_v.js <<'JS'
const ejs = require('ejs'), fs = require('fs');
ejs.compile(fs.readFileSync('views/admin/customers.ejs', 'utf8'), { filename: 'views/admin/customers.ejs' });
console.log('  customers.ejs compiles');
JS
node .gszm_v.js
rm -f .gszm_p.js .gszm_v.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — customer account controls (email, phone, set/reset password) added to the view modal."
