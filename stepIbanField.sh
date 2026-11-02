#!/usr/bin/env bash
# stepIbanField.sh — add a display-only "extra field" (e.g. IBAN) per payment method.
# GSZ side only (payment_logos table, keyed by the reseller-bot method key). Bot + verification untouched.
# Shows an Extra label/value input in /admin/payments and one extra line on checkout under the account.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
for f in routes/adminPayments.js views/admin/payments.ejs routes/checkout.js views/checkout.ejs; do cp -f "$f" "$f.xbak.$TS"; done
restore(){ echo "!! failed — rolling back"; for f in routes/adminPayments.js views/admin/payments.ejs routes/checkout.js views/checkout.ejs; do cp -f "$f.xbak.$TS" "$f"; done; rm -f .gszm_v.js; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> rewrite admin payments route + view"
cat > routes/adminPayments.js <<'GSZM_ADMPAY'
const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');

module.exports = function (pool) {
  const router = express.Router();
  const IMG_DIR = path.join(__dirname, '..', 'public', 'img');
  fs.mkdirSync(IMG_DIR, { recursive: true });

  // display-only per-method metadata (logo/sort/extra) keyed by the reseller-bot method key
  pool.query('CREATE TABLE IF NOT EXISTS payment_logos(key text PRIMARY KEY, logo text, sort int, updated_at timestamptz default now())').catch(function () {});
  pool.query('ALTER TABLE payment_logos ADD COLUMN IF NOT EXISTS extra_label text').catch(function () {});
  pool.query('ALTER TABLE payment_logos ADD COLUMN IF NOT EXISTS extra_value text').catch(function () {});

  const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, IMG_DIR),
    filename: (req, file, cb) => cb(null, '__pmlogo_' + Date.now() + path.extname(file.originalname || '').toLowerCase())
  });
  const okImg = /\.(jpg|jpeg|png|webp|gif|svg)$/i;
  const upload = multer({
    storage,
    limits: { fileSize: 6 * 1024 * 1024 },
    fileFilter: (req, file, cb) => cb(null, okImg.test(file.originalname || ''))
  });

  function auth(req, res, next) {
    if (req.session && req.session.admin) return next();
    return res.redirect('/admin/login');
  }
  function botMod() { try { return require('../lib/botapi'); } catch (e) { return null; } }

  async function logoMap() {
    const map = {};
    try { (await pool.query('SELECT key, logo, sort, extra_label, extra_value FROM payment_logos')).rows.forEach(r => { map[r.key] = { logo: r.logo, sort: (r.sort == null ? 100 : r.sort), extra_label: r.extra_label || '', extra_value: r.extra_value || '' }; }); } catch (e) {}
    return map;
  }

  // --- list live payment methods (from the reseller bot) + their GSZ logos ---
  router.get('/payments', auth, async (req, res) => {
    let methods = [], source = 'bot';
    try {
      const bot = botMod();
      if (bot && bot.configured && bot.configured()) {
        const accts = await bot.getPayAccounts();
        methods = (accts || []).map(a => ({
          key: String(a.key || ''),
          name: a.label || a.method || a.name || a.key,
          currency: String(a.currency || 'PKR').toUpperCase(),
          details: a.details || ((a.title ? ('Title: ' + a.title) : '') + (a.account ? ('\nAccount: ' + a.account) : '')).trim()
        })).filter(m => m.key);
      }
    } catch (e) {}
    if (!methods.length) {
      source = 'local';
      try {
        methods = (await pool.query("SELECT key, name, currency, details FROM payment_methods WHERE active ORDER BY sort, id")).rows
          .map(m => ({ key: m.key, name: m.name, currency: (m.currency || 'PKR'), details: m.details || '' }));
      } catch (e) {}
    }
    const lm = await logoMap();
    methods.forEach(m => { const info = lm[m.key] || {}; m.logo = info.logo || null; m.sort = (info.sort == null ? 100 : info.sort); m.extra_label = info.extra_label || ''; m.extra_value = info.extra_value || ''; });
    methods.sort((a, b) => a.sort - b.sort);
    let priceBuffer = 0; try { const _b = (await pool.query("SELECT value FROM wa_settings WHERE key='price_buffer_pct'")).rows[0]; priceBuffer = _b ? (parseFloat(_b.value) || 0) : 0; } catch (e) {}
    res.render('admin/payments', { methods, source, buffer: priceBuffer, flash: req.query.ok || null, active: 'payments', title: 'Payments' });
  });

  // --- set display order for one method (by bot key) ---
  router.post('/payments/order', auth, express.urlencoded({ extended: true }), async (req, res) => {
    const key = String((req.body && req.body.key) || '').trim();
    const sort = parseInt(req.body && req.body.sort, 10);
    if (!key || !Number.isFinite(sort)) return res.redirect('/admin/payments');
    try {
      await pool.query('INSERT INTO payment_logos(key, sort) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET sort=EXCLUDED.sort, updated_at=now()', [key, sort]);
    } catch (e) {}
    res.redirect('/admin/payments?ok=' + encodeURIComponent('Order updated'));
  });

  // --- set an extra display-only field (e.g. IBAN) for one method (by bot key) ---
  router.post('/payments/extra', auth, express.urlencoded({ extended: true }), async (req, res) => {
    const key = String((req.body && req.body.key) || '').trim();
    if (!key) return res.redirect('/admin/payments');
    const label = String((req.body && req.body.extra_label) || '').trim().slice(0, 40);
    const value = String((req.body && req.body.extra_value) || '').trim().slice(0, 200);
    try {
      await pool.query('INSERT INTO payment_logos(key, extra_label, extra_value) VALUES($1,$2,$3) ON CONFLICT(key) DO UPDATE SET extra_label=EXCLUDED.extra_label, extra_value=EXCLUDED.extra_value, updated_at=now()', [key, label, value]);
    } catch (e) {}
    res.redirect('/admin/payments?ok=' + encodeURIComponent('Extra field saved'));
  });

  // --- upload a logo for one method (by bot key) ---
  router.post('/payments/logo', auth, upload.single('logo'), async (req, res) => {
    const key = String((req.body && req.body.key) || '').trim();
    if (!key) return res.redirect('/admin/payments?ok=' + encodeURIComponent('Missing method'));
    if (!req.file) return res.redirect('/admin/payments?ok=' + encodeURIComponent('Please choose an image file'));
    try {
      const ext = path.extname(req.file.filename).toLowerCase() || '.png';
      const safe = key.replace(/[^a-z0-9_-]/gi, '').slice(0, 40) || 'pm';
      const dest = 'pm-' + safe + '-' + Date.now() + ext;
      fs.renameSync(path.join(IMG_DIR, req.file.filename), path.join(IMG_DIR, dest));
      const prev = (await pool.query('SELECT logo FROM payment_logos WHERE key=$1', [key])).rows[0];
      if (prev && prev.logo && prev.logo !== dest) { try { fs.unlinkSync(path.join(IMG_DIR, prev.logo)); } catch (e) {} }
      await pool.query(
        'INSERT INTO payment_logos(key, logo) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET logo=EXCLUDED.logo, updated_at=now()',
        [key, dest]
      );
      res.redirect('/admin/payments?ok=' + encodeURIComponent('Logo updated'));
    } catch (e) {
      try { fs.unlinkSync(path.join(IMG_DIR, req.file.filename)); } catch (x) {}
      res.redirect('/admin/payments?ok=' + encodeURIComponent('Logo upload failed'));
    }
  });

  // --- remove a logo ---
  router.post('/payments/logo/remove', auth, express.urlencoded({ extended: true }), async (req, res) => {
    const key = String((req.body && req.body.key) || '').trim();
    if (!key) return res.redirect('/admin/payments');
    try {
      const prev = (await pool.query('SELECT logo FROM payment_logos WHERE key=$1', [key])).rows[0];
      if (prev && prev.logo) { try { fs.unlinkSync(path.join(IMG_DIR, prev.logo)); } catch (e) {} }
      await pool.query('DELETE FROM payment_logos WHERE key=$1', [key]);
    } catch (e) {}
    res.redirect('/admin/payments?ok=' + encodeURIComponent('Logo removed'));
  });

  // --- set the foreign-price buffer % (converted local currencies only) ---
  router.post('/payments/buffer', auth, express.urlencoded({ extended: true }), async (req, res) => {
    let v = parseFloat(req.body && req.body.buffer); if (!Number.isFinite(v)) v = 0; v = Math.max(0, Math.min(90, v));
    try { await pool.query("INSERT INTO wa_settings(key,value) VALUES('price_buffer_pct',$1) ON CONFLICT(key) DO UPDATE SET value=$1, updated_at=now()", [String(v)]); } catch (e) {}
    res.redirect('/admin/payments?ok=' + encodeURIComponent('Buffer saved: ' + v + '%'));
  });

  return router;
};
GSZM_ADMPAY

cat > views/admin/payments.ejs <<'GSZM_PAYEJS'
<%- include('_shell_top', { active:'payments', title:'Payments' }) %>
<% if (flash) { %><div class="flash"><%= flash %></div><% } %>
<% var withLogo = methods.filter(function(m){return m.logo;}).length; %>
<div class="dcards">
  <div class="dcard" style="--t:#2a7bff"><span class="dic"><svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20"/></svg></span>
    <div class="dmeta"><span class="dlbl">Methods</span><b class="dval"><%= methods.length %></b><span class="dsub">live at checkout</span></div></div>
  <div class="dcard" style="--t:#16b765"><span class="dic"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/></svg></span>
    <div class="dmeta"><span class="dlbl">With logo</span><b class="dval"><%= withLogo %></b><span class="dsub">of <%= methods.length %></span></div></div>
  <div class="dcard" style="--t:#737e9c"><span class="dic"><svg viewBox="0 0 24 24"><path d="M12 2a10 10 0 1 0 10 10"/><path d="M12 6v6l4 2"/></svg></span>
    <div class="dmeta"><span class="dlbl">Source</span><b class="dval" style="font-size:16px"><%= source==='bot' ? 'Reseller bot' : 'Local' %></b><span class="dsub">of truth</span></div></div>
</div>

<div class="card" style="display:flex;gap:12px;align-items:flex-start">
  <span style="color:#2a7bff;flex:none;margin-top:2px"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg></span>
  <div class="sub" style="margin:0">Payment <b>details</b> (account titles, numbers, instructions) are managed in your <b>reseller bot</b> — the single source of truth. Here you set the <b>logo</b> and an optional <b>extra line</b> (e.g. IBAN) shown on each method's tile at checkout. Upload a <b>square</b> image, <b>256×256</b> recommended (PNG/SVG, transparent or white background).</div>
</div>

<div class="card">
  <h2 style="margin:0 0 4px">Foreign price buffer</h2>
  <div class="sub" style="margin:0 0 12px">Shave a margin off auto-converted foreign prices (your profit). Applies only to the local currencies shown to non-Pakistan visitors — never your PKR prices or your set USD prices. Example: 3% shows a £10 conversion as £9.70.</div>
  <form method="post" action="/admin/payments/buffer" style="display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin:0">
    <input type="range" name="buffer" min="0" max="30" step="0.5" value="<%= Number(buffer||0) %>" oninput="document.getElementById('bufval').textContent=this.value+'%'" style="flex:1;min-width:200px;max-width:380px">
    <b id="bufval" style="min-width:52px;color:#2a7bff;font-size:17px"><%= Number(buffer||0) %>%</b>
    <button class="btn btn-p" type="submit">Save buffer</button>
  </form>
</div>

<% if (!methods.length) { %>
<div class="card"><div class="sub">No payment methods found. Check that your reseller bot is connected.</div></div>
<% } %>

<% methods.forEach(function(m){ %>
<div class="card">
  <div style="display:flex;align-items:center;gap:16px;flex-wrap:wrap">
    <div style="width:60px;height:60px;border-radius:13px;background:#fff;display:flex;align-items:center;justify-content:center;overflow:hidden;border:1px solid rgba(0,0,0,.08);flex:none">
      <% if (m.logo) { %><img src="/static/img/<%= m.logo %>" alt="" style="max-width:100%;max-height:100%;object-fit:contain"><% } else { %><span style="font-weight:800;color:#2a7bff;font-size:22px"><%= (m.name||'?').charAt(0).toUpperCase() %></span><% } %>
    </div>
    <div style="flex:1;min-width:160px">
      <h2 style="margin:0 0 2px"><%= m.name %> <span style="color:var(--muted);font-weight:600;font-size:12.5px">· <%= m.key %></span></h2>
      <div class="sub" style="margin:0"><%= m.currency %><% if (m.logo) { %> · <span style="color:#16b765;font-weight:700">logo set</span><% } else { %> · no logo yet<% } %><% if (m.extra_value) { %> · <span style="color:#2a7bff;font-weight:700"><%= m.extra_label || 'Extra' %> set</span><% } %></div>
    </div>
    <form method="post" action="/admin/payments/order" style="display:flex;align-items:center;gap:6px;margin:0">
      <input type="hidden" name="key" value="<%= m.key %>">
      <label class="fld" style="margin:0 2px 0 0">Order</label>
      <input type="number" name="sort" value="<%= m.sort %>" min="1" style="width:62px">
      <button class="btn" type="submit">Set</button>
    </form>
    <form method="post" action="/admin/payments/logo" enctype="multipart/form-data" style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin:0">
      <input type="hidden" name="key" value="<%= m.key %>">
      <input type="file" name="logo" accept="image/png,image/jpeg,image/webp,image/svg+xml,image/gif" required style="max-width:220px">
      <button class="btn btn-p" type="submit"><%= m.logo ? 'Replace' : 'Upload' %> logo</button>
    </form>
    <% if (m.logo) { %>
    <form method="post" action="/admin/payments/logo/remove" style="margin:0">
      <input type="hidden" name="key" value="<%= m.key %>">
      <button class="btn" type="submit">Remove</button>
    </form>
    <% } %>
  </div>
  <form method="post" action="/admin/payments/extra" style="display:flex;align-items:flex-end;gap:10px;flex-wrap:wrap;margin:14px 0 0;padding-top:14px;border-top:1px solid var(--hair)">
    <input type="hidden" name="key" value="<%= m.key %>">
    <div><label class="fld" style="margin:0 0 5px">Extra label</label><input type="text" name="extra_label" value="<%= m.extra_label || '' %>" placeholder="IBAN" maxlength="40" style="width:130px"></div>
    <div style="flex:1;min-width:220px"><label class="fld" style="margin:0 0 5px">Extra value <span style="color:var(--muted);font-weight:500">(shown on checkout under the account)</span></label><input type="text" name="extra_value" value="<%= m.extra_value || '' %>" placeholder="e.g. PK36MEZN0000001234567890" maxlength="200"></div>
    <button class="btn btn-p" type="submit">Save extra</button>
  </form>
</div>
<% }); %>
<%- include('_shell_bottom') %>
GSZM_PAYEJS

echo "==> patch checkout route + view (exact anchors)"
cat > /tmp/gszm_patch_checkout.js <<'GSZM_PATCH'
const fs = require('fs');
function one(file, anchor, repl, label) {
  let s = fs.readFileSync(file, 'utf8');
  const n = s.split(anchor).length - 1;
  if (n !== 1) throw new Error(label + ': anchor not unique (' + n + ') in ' + file);
  fs.writeFileSync(file, s.split(anchor).join(repl));
  console.log('  patched: ' + label);
}
// idempotency guard
if (fs.readFileSync('routes/checkout.js','utf8').indexOf('_attachExtras') >= 0) { console.log('  checkout.js already patched'); }
else {
  const helper =
"async function _attachExtras(arr) {\n" +
"    try {\n" +
"      if (!arr || !arr.length) return arr;\n" +
"      const _ex = {};\n" +
"      (await pool.query('SELECT key, extra_label, extra_value FROM payment_logos')).rows.forEach(function (r) { _ex[r.key] = r; });\n" +
"      arr.forEach(function (m) { const e = _ex[m.key]; if (e && e.extra_value) { m.extra_label = e.extra_label || 'IBAN'; m.extra_value = e.extra_value; } });\n" +
"    } catch (e) {}\n" +
"    return arr;\n" +
"  }\n\n  ";
  one('routes/checkout.js', 'async function payMethods(region, pkr, usd) {', helper + 'async function payMethods(region, pkr, usd) {', 'checkout helper');
  one('routes/checkout.js', 'return { methods: list, botAcct: true };', 'return { methods: await _attachExtras(list), botAcct: true };', 'bot methods extras');
  one('routes/checkout.js', 'return { methods, botAcct: false };', 'return { methods: await _attachExtras(methods), botAcct: false };', 'local methods extras');
}
const ev = fs.readFileSync('views/checkout.ejs','utf8');
if (ev.indexOf('pm-extra') >= 0) { console.log('  checkout.ejs already patched'); }
else {
  one('views/checkout.ejs',
    '<% if (det.trim()) { %><div class="pm-details"><%= det %></div><% } %>',
    '<% if (det.trim()) { %><div class="pm-details"><%= det %></div><% } %>\n              <% if (m.extra_value) { %><div class="pm-details pm-extra"><%= (m.extra_label||\'IBAN\') %>: <%= m.extra_value %></div><% } %>',
    'checkout extra line');
}
GSZM_PATCH
node /tmp/gszm_patch_checkout.js

echo "==> validating"
node --check routes/adminPayments.js
node --check routes/checkout.js
cat > .gszm_v.js <<'GSZM_V'
const ejs = require('ejs'), fs = require('fs');
// admin payments renders (real _shell_top/_shell_bottom on server)
const methods=[{key:'meezan',name:'Meezan Bank',currency:'PKR',logo:null,sort:1,extra_label:'IBAN',extra_value:'PK36MEZN0000001234567890'},{key:'binance',name:'Binance',currency:'USDT',logo:null,sort:2,extra_label:'',extra_value:''}];
ejs.render(fs.readFileSync('views/admin/payments.ejs','utf8'),{methods,source:'bot',buffer:3,flash:null,active:'payments',title:'Payments'},{filename:'views/admin/payments.ejs'});
console.log('  admin payments renders');
// checkout view compiles (full render needs many locals; syntax check is enough for the one-line add)
ejs.compile(fs.readFileSync('views/checkout.ejs','utf8'),{filename:'views/checkout.ejs'});
console.log('  checkout view compiles');
GSZM_V
node .gszm_v.js
rm -f .gszm_v.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — Extra field (IBAN) added. Set it per method in /admin/payments; it shows on checkout under the account."
