#!/usr/bin/env bash
# stepZayronCustomersAdmin — build the admin Customers page (list + search + per-customer manage),
# with "Change WhatsApp number" that forces re-verify (sets phone_verified=false + sends a code to the
# new number). Also sync the customer verify-phone screen to read the current DB number.
# Files: routes/admin.js, routes/account.js. File-based anchors. Safe: backup, single-match + revert, check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp routes/admin.js "$B/"; cp routes/account.js "$B/"
revert(){ cp "$B/admin.js" routes/admin.js; cp "$B/account.js" routes/account.js; pm2 restart zayron >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# ---- admin.js: add Customers routes before module.exports ----
cat > "$T/ao" <<'O'
module.exports = router;
O
cat > "$T/an" <<'O'
// ---------- CUSTOMERS ----------
router.get('/customers', async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim();
    let where = '', params = [];
    if (q) { where = "WHERE c.phone ILIKE $1 OR c.name ILIKE $1"; params = ['%' + q + '%']; }
    const rows = (await pool.query("SELECT c.id, c.name, c.phone, c.phone_verified, c.created_at, c.status, (SELECT COUNT(*)::int FROM orders o WHERE o.customer_id=c.id) AS orders FROM customers c " + where + " ORDER BY c.id DESC LIMIT 200", params)).rows;
    const fmt = d => { try { return new Date(d).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }); } catch (e) { return '-'; } };
    const list = rows.map(c => `<tr>
      <td><b>${esc(c.name || '-')}</b></td>
      <td style="font-family:ui-monospace,monospace">+${esc(c.phone || '')}</td>
      <td>${c.phone_verified ? '<span style="color:#15803d;font-weight:600">Verified</span>' : '<span style="color:#c2410c;font-weight:600">Not verified</span>'}</td>
      <td>${c.orders || 0}</td>
      <td>${esc(fmt(c.created_at))}</td>
      <td class="right"><a class="btn ghost sm" href="/admin/customers/${c.id}">Manage</a></td>
    </tr>`).join('');
    res.send(layout('Customers', `<h1>Customers</h1><p class="sub">Everyone who signed up on the site. Change a number here and the customer must re-verify it before ordering again.</p>
      <form method="get" action="/admin/customers" style="margin-bottom:12px"><input name="q" value="${esc(q)}" placeholder="Search name or number" style="max-width:280px"> <button class="btn" type="submit">Search</button></form>
      <div class="card mt"><table><tr><th>Name</th><th>WhatsApp</th><th>Status</th><th>Orders</th><th>Joined</th><th></th></tr>${list || '<tr><td colspan=6 class=muted>No customers yet.</td></tr>'}</table></div>`, '/admin/customers'));
  } catch (e) { next(e); }
});
router.get('/customers/:id', async (req, res, next) => {
  try {
    const cu = (await pool.query('SELECT * FROM customers WHERE id=$1', [req.params.id])).rows[0];
    if (!cu) return res.status(404).send('Not found');
    const orders = (await pool.query("SELECT ref, plan_label, status FROM orders WHERE customer_id=$1 ORDER BY id DESC LIMIT 20", [cu.id])).rows;
    const olist = orders.map(o => `<tr><td>${esc(o.ref)}</td><td>${esc(o.plan_label || '')}</td><td>${esc(o.status || '')}</td></tr>`).join('') || '<tr><td colspan=3 class=muted>No orders.</td></tr>';
    const flash = req.query.msg ? `<div class="card" style="background:#f0fdf6;border-color:#bbf7d0;color:#0e9257">${esc(req.query.msg)}</div>` : '';
    res.send(layout('Customer', `${flash}<h1>${esc(cu.name || 'Customer')}</h1><p class="sub">+${esc(cu.phone)} &middot; ${cu.phone_verified ? 'Verified' : 'Not verified'}</p>
      <div class="card"><label>Change WhatsApp number</label><div class="hint">Sends a verification code to the new number. The customer is blocked from new trials and orders until they verify it.</div>
        <form method="post" action="/admin/customers/${cu.id}/phone" style="margin-top:8px"><input name="phone" placeholder="923001234567" style="max-width:260px"> <button class="btn" type="submit">Change &amp; require re-verify</button></form></div>
      <div class="card mt"><p class="hd">Recent orders</p><table><tr><th>Ref</th><th>Plan</th><th>Status</th></tr>${olist}</table></div>
      <a class="btn ghost mt" href="/admin/customers">&larr; Back to customers</a>`, '/admin/customers'));
  } catch (e) { next(e); }
});
router.post('/customers/:id/phone', require('express').urlencoded({ extended: true }), async (req, res, next) => {
  try {
    const id = req.params.id;
    const newPhone = String((req.body || {}).phone || '').replace(/[^0-9]/g, '');
    if (newPhone.length < 10 || newPhone.length > 15) return res.redirect('/admin/customers/' + id + '?msg=' + encodeURIComponent('Enter a valid number with country code.'));
    const dup = (await pool.query('SELECT id FROM customers WHERE phone=$1 AND id<>$2', [newPhone, id])).rows[0];
    if (dup) return res.redirect('/admin/customers/' + id + '?msg=' + encodeURIComponent('That number is already used by another account.'));
    const code = String(Math.floor(100000 + Math.random() * 900000));
    await pool.query("UPDATE customers SET phone=$1, phone_verified=false, otp_code=$2, otp_expires=now() + interval '10 minutes' WHERE id=$3", [newPhone, code, id]);
    await pool.query("INSERT INTO otp_outbox (phone, body, status) VALUES ($1,$2,'queued')", [newPhone, 'Your Zayron verification code is: ' + code + '. It expires in 10 minutes.']);
    return res.redirect('/admin/customers/' + id + '?msg=' + encodeURIComponent('Number changed to +' + newPhone + ' and a code was sent. The customer must verify before ordering.'));
  } catch (e) { next(e); }
});

module.exports = router;
O

# ---- account.js: verify-phone reads current DB number ----
cat > "$T/co" <<'O'
  router.get('/verify-phone', requireLogin, async (req, res) => {
    const c = me(req); const err = req.session.flash; delete req.session.flash;
    res.send(shellPage('Verify your number — Zayron', verifyPhonePage(c, err || ''), await deps.getPublicData(), { noindex:true }));
  });
O
cat > "$T/cn" <<'O'
  router.get('/verify-phone', requireLogin, async (req, res) => {
    const c = me(req); const err = req.session.flash; delete req.session.flash;
    try { const _r = (await pool.query('SELECT phone FROM customers WHERE id=$1', [c.id])).rows[0]; if (_r && _r.phone) { c.phone = _r.phone; if (req.session.customer) req.session.customer.phone = _r.phone; } } catch (e) {}
    res.send(shellPage('Verify your number — Zayron', verifyPhonePage(c, err || ''), await deps.getPublicData(), { noindex:true }));
  });
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('routes/admin.js', [['ao','an']]);
patch('routes/account.js', [['co','cn']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/admin.js && node --check routes/account.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: Customers admin page live (list + change-number -> re-verify). healthz=200"
