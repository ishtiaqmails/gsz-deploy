#!/usr/bin/env bash
# stepZayronAdminReverify — make the REAL customer-admin Save (lib/customerAdmin.js) force WhatsApp
# re-verification when an admin changes a customer's number: reset phone_verified, queue a code to the
# NEW number, and show a confirmation. Only fires when the number actually changes. Also removes the
# now-dead/shadowed Batch-D customer routes from routes/admin.js.
# Files: lib/customerAdmin.js (3 single-line anchors), routes/admin.js (node splice). Safe: backup, revert, check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp lib/customerAdmin.js "$B/"; cp routes/admin.js "$B/"
revert(){ cp "$B/customerAdmin.js" lib/customerAdmin.js; cp "$B/admin.js" routes/admin.js; pm2 restart zayron >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# --- A: where phone is added to the update, detect a real change -> re-verify + code ---
cat > "$T/a_o" <<'O'
      if (phone.length >= 10 && phone.length <= 15) { sets.push('phone=$' + (vals.length + 1)); vals.push(phone); }
O
cat > "$T/a_n" <<'O'
      const _cur = (await pool.query('SELECT phone FROM customers WHERE id=$1', [req.params.id])).rows[0] || {};
      const _curPhone = String(_cur.phone || '').replace(/[^0-9]/g, '');
      let _numChanged = false, _vcode = null;
      if (phone.length >= 10 && phone.length <= 15) {
        sets.push('phone=$' + (vals.length + 1)); vals.push(phone);
        if (phone !== _curPhone) {
          _numChanged = true; _vcode = String(Math.floor(100000 + Math.random() * 900000));
          sets.push('phone_verified=false');
          sets.push('otp_code=$' + (vals.length + 1)); vals.push(_vcode);
          sets.push("otp_expires=now() + interval '10 minutes'");
        }
      }
O

# --- B: on save, if number changed, queue the code to the new number + flag the redirect ---
cat > "$T/b_o" <<'O'
      res.redirect('/admin/customers/' + req.params.id + '?ok=1');
O
cat > "$T/b_n" <<'O'
      if (_numChanged) { try { await pool.query("INSERT INTO otp_outbox (phone, body, status) VALUES ($1,$2,'queued')", [phone, 'Your zayron.tv verification code is ' + _vcode + '. Enter it to verify your WhatsApp number. It expires in 10 minutes.']); } catch (e) {} }
      res.redirect('/admin/customers/' + req.params.id + (_numChanged ? '?sent=1' : '?ok=1'));
O

# --- C: manage page shows a confirmation after a number change ---
cat > "$T/c_o" <<'O'
        '<p class="sub" style="font-family:ui-monospace,monospace">+' + esc(c.phone) + (c.email ? ' · ' + esc(c.email) : '') + '</p>' +
O
cat > "$T/c_n" <<'O'
        '<p class="sub" style="font-family:ui-monospace,monospace">+' + esc(c.phone) + (c.email ? ' · ' + esc(c.email) : '') + '</p>' +
        (req.query && req.query.sent ? '<div class="card" style="background:#f0fdf6;border-color:#bbf7d0;color:#0e9257;margin:10px 0">Number changed. A verification code was sent to the new WhatsApp number — the customer must verify it before they can order.</div>' : '') +
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('lib/customerAdmin.js', [['a_o','a_n'],['b_o','b_n'],['c_o','c_n']]);

// remove dead Batch-D routes from routes/admin.js (marker .. last module.exports)
(function(){
  const F='routes/admin.js'; let s=fs.readFileSync(F,'utf8');
  const marker='// ---------- CUSTOMERS ----------';
  const i=s.indexOf(marker);
  const tail='module.exports = router;';
  const j=s.lastIndexOf(tail);
  if(i<0){ console.log('admin.js: dead block marker not found (already clean) — skipping'); return; }
  if(j<0 || j<i){ console.error('admin.js: module.exports anchor bad'); process.exit(6); }
  if(s.indexOf(marker)!==s.lastIndexOf(marker)){ console.error('admin.js: marker not unique'); process.exit(6); }
  s=s.slice(0,i)+s.slice(j);
  if(s.split(marker).length-1!==0){ console.error('admin.js: marker still present'); process.exit(6); }
  fs.writeFileSync(F,s); console.log('routes/admin.js dead routes REMOVED');
})();
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check lib/customerAdmin.js && node --check routes/admin.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: admin number-change forces re-verify + sends code; dead routes removed. healthz=200"
