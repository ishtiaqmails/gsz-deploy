#!/usr/bin/env bash
# stepMaintUpload.sh — add a "Maintenance logo" uploader to GSZ admin so the logo is managed from the dashboard.
# Updates lib/maintenance.js, routes/adminMaintenance.js and both views. Validates, restarts, rolls back on failure.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
for f in lib/maintenance.js routes/adminMaintenance.js views/admin/maintenance.ejs views/maintenance.ejs; do cp -f "$f" "$f.xbak.$TS"; done
restore(){ echo "!! failed — rolling back"; for f in lib/maintenance.js routes/adminMaintenance.js views/admin/maintenance.ejs views/maintenance.ejs; do cp -f "$f.xbak.$TS" "$f"; done; rm -f .gszm_v.js; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> updating files"
cat > lib/maintenance.js <<'GSZM_LIB'
'use strict';
/* lib/maintenance.js — public maintenance gate for galaxyzayron.store.
 * Reads admin settings (the `settings` table) into memory, refreshed every 10s, so the
 * middleware never touches the DB per request. FAILS OPEN: any error -> site stays up.
 * Skips /admin, /static, /api, /internal, sitemap/robots/well-known, logged-in admins and a
 * preview token — so the admin dashboard, bots and SEO are never affected. Other subdomains
 * are separate apps and are untouched by definition. */
module.exports = function (pool) {
  var cache = { on: false, data: {} };
  function refresh() {
    pool.query("SELECT key,value FROM settings WHERE key LIKE 'maint_%'")
      .then(function (r) {
        var o = {};
        (r.rows || []).forEach(function (x) { o[x.key] = x.value; });
        cache = { on: o.maint_on === '1', data: o };
      })
      .catch(function () { /* keep last good cache; never block the site */ });
  }
  refresh();
  var t = setInterval(refresh, 10000);
  if (t && t.unref) t.unref();

  var SKIP = /^\/(admin|static|api|internal|sitemap|robots\.txt|favicon|\.well-known)/i;

  return function (req, res, next) {
    try {
      if (!cache.on) return next();
      if (req.method !== 'GET' && req.method !== 'HEAD') return next();
      if (SKIP.test(req.path || '')) return next();
      if (req.session && req.session.admin) return next();
      var tok = cache.data.maint_token || '';
      if (tok && req.query && req.query.gpv === tok) { if (req.session) req.session.gsz_pv = true; return next(); }
      if (req.session && req.session.gsz_pv) return next();
      var d = cache.data;
      res.set('Retry-After', '3600');
      return res.status(503).render('maintenance', {
        logo: d.maint_logo ? ('/static/img/' + d.maint_logo) : '/static/img/logo.png',
        statusText: d.maint_status || 'Scheduled maintenance',
        title: d.maint_title || "We'll be back shortly",
        message: d.maint_message || "Our store is briefly offline for scheduled maintenance. We'll be back very soon — thanks for your patience.",
        endTime: d.maint_until || '',
        supportEmail: d.maint_email || 'orders@galaxyzayron.store',
        whatsapp: d.maint_wa || ''
      });
    } catch (e) { return next(); }
  };
};
GSZM_LIB

cat > routes/adminMaintenance.js <<'GSZM_ROUTE'
'use strict';
const express = require('express');
const crypto = require('crypto');
const multer = require('multer');
const path = require('path');
module.exports = function (pool) {
  const router = express.Router();
  const storage = multer.diskStorage({
    destination: function (req, file, cb) { cb(null, path.join(__dirname, '..', 'public', 'img')); },
    filename: function (req, file, cb) {
      let ext = path.extname(file.originalname || '').toLowerCase();
      if (!/^\.(png|jpg|jpeg|webp|svg)$/.test(ext)) ext = '.png';
      cb(null, 'maint-logo' + ext);
    }
  });
  const upload = multer({ storage: storage, limits: { fileSize: 6 * 1024 * 1024 } });
  function logoUrl(s) { return s.maint_logo ? ('/static/img/' + s.maint_logo) : '/static/img/logo.png'; }
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }
  async function load() {
    const o = {};
    (await pool.query("SELECT key,value FROM settings WHERE key LIKE 'maint_%'")).rows.forEach(r => { o[r.key] = r.value; });
    return o;
  }
  async function put(k, v) { await pool.query('INSERT INTO settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value', [k, v]); }

  router.get('/maintenance', auth, async (req, res) => {
    const s = await load();
    if (!s.maint_token) { s.maint_token = crypto.randomBytes(9).toString('hex'); await put('maint_token', s.maint_token); }
    res.render('admin/maintenance', { s, logo: logoUrl(s), flash: req.query.ok || null, active: 'maintenance', title: 'Maintenance' });
  });

  router.post('/maintenance/save', auth, express.urlencoded({ extended: true }), async (req, res) => {
    const b = req.body || {};
    const on = (String(b.on) === '1') ? '1' : '0';
    await put('maint_on', on);
    for (const k of ['maint_status', 'maint_title', 'maint_message', 'maint_until', 'maint_email', 'maint_wa']) {
      await put(k, (b[k] != null ? String(b[k]) : '').trim());
    }
    const cur = await load();
    if (!cur.maint_token) await put('maint_token', crypto.randomBytes(9).toString('hex'));
    res.redirect('/admin/maintenance?ok=' + (on === '1' ? 'Maintenance+is+ON' : 'Site+is+live+again'));
  });

  router.get('/maintenance/preview', auth, async (req, res) => {
    const d = await load();
    res.render('maintenance', {
      logo: logoUrl(d),
      statusText: d.maint_status || 'Scheduled maintenance',
      title: d.maint_title || "We'll be back shortly",
      message: d.maint_message || "Our store is briefly offline for scheduled maintenance. We'll be back very soon — thanks for your patience.",
      endTime: d.maint_until || '',
      supportEmail: d.maint_email || 'orders@galaxyzayron.store',
      whatsapp: d.maint_wa || ''
    });
  });

  router.post('/maintenance/logo', auth, upload.single('logo'), async (req, res) => {
    if (req.file && req.file.filename) await put('maint_logo', req.file.filename);
    res.redirect('/admin/maintenance?ok=' + (req.file ? 'Logo+updated' : 'No+file+selected'));
  });

  return router;
};
GSZM_ROUTE

cat > views/admin/maintenance.ejs <<'GSZM_ADM'
<%- include('_shell_top', { active:'maintenance', title:'Maintenance' }) %>
<% var on = (s.maint_on === '1'); %>
<% if (flash) { %><div class="flash"><%= flash %></div><% } %>

<div class="dcards">
  <div class="dcard" style="--t:<%= on ? '#e0453f' : '#16b765' %>">
    <div class="dic"><svg viewBox="0 0 24 24"><path d="M12 2a10 10 0 1 0 10 10"/><path d="M12 6v6l4 2"/></svg></div>
    <div class="dmeta"><div class="dlbl">Current status</div><div class="dval"><%= on ? 'Maintenance ON' : 'Site is live' %></div><div class="dsub<%= on ? ' alert' : '' %>"><%= on ? 'Visitors see the maintenance page' : 'Everything is running normally' %></div></div>
  </div>
  <div class="dcard" style="--t:#8a2bff">
    <div class="dic"><svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg></div>
    <div class="dmeta"><div class="dlbl">Back online at</div><div class="dval"><%= s.maint_until ? s.maint_until.replace('T',' ') : 'Not set' %></div><div class="dsub">Shown as a live countdown</div></div>
  </div>
  <div class="dcard" style="--t:#2a7bff">
    <div class="dic"><svg viewBox="0 0 24 24"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg></div>
    <div class="dmeta"><div class="dlbl">Preview</div><div class="dval" style="font-size:16px"><a href="/admin/maintenance/preview" target="_blank" style="color:var(--brand)">Open the page ↗</a></div><div class="dsub">See exactly what visitors see</div></div>
  </div>
</div>

<form method="post" action="/admin/maintenance/save">
  <div class="card">
    <h2>One-click switch</h2>
    <p class="hint">Turn your public store into the maintenance page. Your admin dashboard, bots and other subdomains are never affected — only galaxyzayron.store visitors see it. You (logged in here) always see the real site.</p>
    <div style="display:flex;gap:10px;flex-wrap:wrap;align-items:center">
      <% if (on) { %>
        <button class="btn btn-p" name="on" value="0" type="submit" style="background:linear-gradient(118deg,#16b765,#0f9e86)">● Turn OFF — go live</button>
        <span class="spill" style="background:#fdeceb;color:#e0453f">Maintenance is ON</span>
      <% } else { %>
        <button class="btn btn-p" name="on" value="1" type="submit" style="background:linear-gradient(118deg,#e0453f,#f5a623)">● Turn ON maintenance</button>
        <span class="spill" style="background:#e9fbf1;color:#0b7a42">Site is live</span>
      <% } %>
      <a class="btn btn-g" href="/admin/maintenance/preview" target="_blank">Preview page ↗</a>
    </div>
  </div>

  <div class="card">
    <h2>Page content</h2>
    <p class="hint">What visitors read on the maintenance page. The countdown uses the time below.</p>
    <label class="fld">Status label</label>
    <input type="text" name="maint_status" value="<%= s.maint_status || 'Scheduled maintenance' %>" placeholder="Scheduled maintenance">
    <label class="fld">Headline</label>
    <input type="text" name="maint_title" value="<%= s.maint_title || 'We\'ll be back shortly' %>" placeholder="We'll be back shortly">
    <label class="fld">Message</label>
    <textarea name="maint_message" rows="3" placeholder="Short friendly message"><%= s.maint_message || "Our store is briefly offline for scheduled maintenance. We'll be back very soon — thanks for your patience." %></textarea>
    <label class="fld">Back online at (for the countdown)</label>
    <input type="datetime-local" name="maint_until" value="<%= s.maint_until || '' %>">
    <label class="fld">WhatsApp number (powers the "Contact us on WhatsApp" button)</label>
    <input type="text" name="maint_wa" value="<%= s.maint_wa || '' %>" placeholder="923001234567">
    <p class="hint" style="margin-top:-4px">Use full international format with country code, e.g. 923001234567. Leave empty to hide the button.</p>
    <button class="btn btn-p" name="on" value="<%= on ? '1' : '0' %>" type="submit">Save changes</button>
  </div>
</form>

<form method="post" action="/admin/maintenance/logo" enctype="multipart/form-data">
  <div class="card">
    <h2>Maintenance logo</h2>
    <p class="hint">Shown big on the maintenance page. Upload a transparent PNG or WebP around 1000px wide for a large, crisp result. Leave it and the page uses your site logo.</p>
    <div style="background:#0c1020;border:1px solid var(--hair);border-radius:12px;padding:18px;display:flex;align-items:center;justify-content:center;margin-bottom:14px">
      <img src="<%= logo %>" alt="Current maintenance logo" style="max-width:280px;max-height:120px;object-fit:contain">
    </div>
    <input type="file" name="logo" accept="image/png,image/webp,image/jpeg,image/svg+xml" required>
    <button class="btn btn-p" type="submit" style="margin-top:10px">Upload logo</button>
  </div>
</form>
<%- include('_shell_bottom') %>
GSZM_ADM

cat > views/maintenance.ejs <<'GSZM_PUB'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="robots" content="noindex">
<title><%= statusText %> — Galaxy Subz × Zayron</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Sora:wght@400;500;600;700;800&family=Inter:wght@400;500;600&display=swap">
<style>
:root{--bg:#070912;--ink:#eef1ff;--muted:#8b93bb;--faint:#5b6186;--line:rgba(255,255,255,.09);--card:rgba(255,255,255,.04);
  --v:#8b45ff;--b:#3b82ff;--c:#28d6ff;--brand:linear-gradient(100deg,#8b45ff,#3b82ff 55%,#28d6ff);
  --glow:0 10px 40px rgba(59,130,255,.35);--disp:'Sora',system-ui,sans-serif;--body:'Inter',system-ui,-apple-system,sans-serif;color-scheme:dark}
*{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%}
body{background:var(--bg);color:var(--ink);font-family:var(--body);min-height:100svh;display:flex;align-items:center;justify-content:center;overflow:hidden;position:relative;padding:max(22px,env(safe-area-inset-left)) max(22px,env(safe-area-inset-right))}
#sky{position:fixed;inset:0;z-index:0;display:block}
.nebula{position:fixed;z-index:0;border-radius:50%;filter:blur(90px);opacity:.5;pointer-events:none}
.n1{width:60vmax;height:60vmax;left:-20vmax;top:-25vmax;background:radial-gradient(circle,rgba(139,69,255,.55),transparent 65%)}
.n2{width:55vmax;height:55vmax;right:-22vmax;bottom:-25vmax;background:radial-gradient(circle,rgba(40,214,255,.4),transparent 65%)}
.vignette{position:fixed;inset:0;z-index:1;pointer-events:none;background:radial-gradient(120% 90% at 50% 40%,transparent 55%,rgba(5,6,14,.85) 100%)}
.stage{position:relative;z-index:2;width:100%;max-width:720px;text-align:center;display:flex;flex-direction:column;align-items:center;gap:clamp(16px,2.6vh,30px)}
.brandwrap{position:relative;display:flex;align-items:center;justify-content:center}
.brandwrap::before{content:"";position:absolute;width:92%;height:92%;left:4%;top:4%;background:radial-gradient(circle,rgba(99,102,241,.34),transparent 70%);filter:blur(52px);z-index:-1;pointer-events:none}
.logo{max-width:min(440px,86vw);max-height:min(360px,42vh);width:auto;height:auto;filter:drop-shadow(0 12px 42px rgba(59,130,255,.42))}
.chip{display:inline-flex;align-items:center;gap:.5rem;background:var(--card);border:1px solid var(--line);border-radius:999px;padding:.42rem .95rem;font-size:.8rem;font-weight:600;color:var(--ink);letter-spacing:.02em}
.chip .dot{width:8px;height:8px;border-radius:50%;background:#ffd35c;box-shadow:0 0 10px #ffd35c;animation:pulse 1.6s infinite}
h1{font-family:var(--disp);font-weight:800;line-height:1.05;letter-spacing:-.02em;font-size:clamp(2rem,6.4vw,3.6rem)}
.lead{color:var(--muted);font-size:clamp(1rem,2.4vw,1.15rem);max-width:46ch;line-height:1.6}
.count{display:flex;gap:clamp(8px,2vw,16px);justify-content:center}
.unit{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:clamp(12px,2vh,18px) clamp(10px,2.4vw,22px);min-width:clamp(62px,17vw,92px);backdrop-filter:blur(8px)}
.unit .num{font-family:var(--disp);font-weight:800;font-size:clamp(1.7rem,6vw,2.8rem);line-height:1;font-variant-numeric:tabular-nums;background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent}
.unit .lbl{margin-top:.5rem;font-size:.72rem;letter-spacing:.14em;text-transform:uppercase;color:var(--faint)}
.eta{font-size:.9rem;color:var(--muted)}
.eta b{color:var(--ink);font-weight:600}
.contact{display:flex;flex-wrap:wrap;gap:10px;justify-content:center;margin-top:2px}
.contact .btn{display:inline-flex;align-items:center;gap:.5rem;border-radius:999px;padding:.6rem 1.15rem;font-size:.92rem;font-weight:600;border:1px solid var(--line);background:var(--card);color:var(--ink);cursor:pointer;transition:.16s;text-decoration:none}
.contact .btn:hover{border-color:rgba(255,255,255,.28);transform:translateY(-2px)}
.contact .btn.g{background:var(--brand);border-color:transparent;box-shadow:var(--glow)}
.foot{position:fixed;left:0;right:0;bottom:max(14px,env(safe-area-inset-bottom));z-index:2;text-align:center;color:var(--faint);font-size:.78rem}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.35}}
@media (prefers-reduced-motion:reduce){.chip .dot{animation:none}}
@media (max-height:640px){.logo{max-height:38vh}}
</style>
</head>
<body>
<canvas id="sky"></canvas>
<div class="nebula n1"></div>
<div class="nebula n2"></div>
<div class="vignette"></div>
<main class="stage">
  <div class="brandwrap"><img class="logo" src="<%= logo %>" alt="Galaxy Subz × Zayron" onerror="this.style.display='none'"></div>
  <span class="chip"><span class="dot"></span> <%= statusText %></span>
  <h1><%= title %></h1>
  <p class="lead"><%= message %></p>
  <% if (endTime) { %>
  <div class="count" id="count" aria-live="polite">
    <div class="unit"><div class="num" id="d">00</div><div class="lbl">Days</div></div>
    <div class="unit"><div class="num" id="h">00</div><div class="lbl">Hours</div></div>
    <div class="unit"><div class="num" id="m">00</div><div class="lbl">Minutes</div></div>
    <div class="unit"><div class="num" id="s">00</div><div class="lbl">Seconds</div></div>
  </div>
  <p class="eta" id="eta"></p>
  <% } %>
  <div class="contact">
    <a class="btn g" id="waBtn" href="#" target="_blank" rel="noopener" style="display:none"><svg viewBox="0 0 24 24" width="19" height="19" fill="currentColor" aria-hidden="true"><path d="M19.05 4.91A9.82 9.82 0 0 0 12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2 22l5.25-1.38a9.9 9.9 0 0 0 4.79 1.22h.004c5.46 0 9.91-4.45 9.91-9.91 0-2.65-1.03-5.14-2.9-7.02zm-7.01 15.24h-.003a8.23 8.23 0 0 1-4.19-1.15l-.3-.18-3.12.82.83-3.04-.2-.31a8.2 8.2 0 0 1-1.26-4.39c0-4.54 3.7-8.23 8.24-8.23a8.2 8.2 0 0 1 5.82 2.41 8.18 8.18 0 0 1 2.41 5.83c0 4.54-3.7 8.24-8.24 8.24zm4.52-6.16c-.25-.12-1.47-.72-1.69-.81-.23-.08-.39-.12-.56.12-.17.25-.64.81-.79.97-.14.17-.29.19-.54.06-.25-.12-1.05-.39-1.99-1.23-.74-.66-1.23-1.47-1.38-1.72-.14-.25-.02-.38.11-.5.11-.11.25-.29.37-.43.12-.14.17-.25.25-.41.08-.17.04-.31-.02-.43-.06-.12-.56-1.34-.76-1.84-.2-.48-.41-.42-.56-.43h-.48c-.17 0-.43.06-.66.31-.23.25-.86.85-.86 2.07 0 1.22.89 2.4 1.01 2.56.12.17 1.75 2.67 4.23 3.74.59.26 1.05.41 1.41.52.59.19 1.13.16 1.56.1.48-.07 1.47-.6 1.68-1.18.21-.58.21-1.07.14-1.18-.06-.1-.22-.16-.47-.28z"/></svg> Contact us on WhatsApp</a>
  </div>
</main>
<div class="foot">© <span id="yr"></span> Galaxy Subz × Zayron</div>
<script>
var CONFIG = {
  endTime: <%- JSON.stringify(endTime || '') %>,
  whatsapp: <%- JSON.stringify(whatsapp || '') %>
};
document.getElementById('yr').textContent = new Date().getFullYear();
var wa = document.getElementById('waBtn');
if (CONFIG.whatsapp) { wa.href = 'https://wa.me/' + CONFIG.whatsapp; wa.style.display = 'inline-flex'; }
if (CONFIG.endTime) {
  var end = new Date(CONFIG.endTime).getTime();
  var eta = document.getElementById('eta');
  try { eta.innerHTML = 'Expected back by <b>' + new Date(end).toLocaleString(undefined, { weekday: 'short', hour: '2-digit', minute: '2-digit', day: 'numeric', month: 'short' }) + '</b>'; } catch (e) {}
  var pad = function (n) { return (n < 10 ? '0' : '') + n; };
  var timer = setInterval(tick, 1000);
  function tick() {
    var diff = end - Date.now();
    if (isNaN(diff) || diff <= 0) {
      var cEl = document.getElementById('count');
      if (cEl) cEl.innerHTML = "<div class='unit' style='min-width:auto'><div class='num'>Soon</div><div class='lbl'>Back online</div></div>";
      if (eta) eta.textContent = "We're back any moment — please refresh.";
      clearInterval(timer); return;
    }
    var s = Math.floor(diff / 1000);
    document.getElementById('d').textContent = pad(Math.floor(s / 86400));
    document.getElementById('h').textContent = pad(Math.floor(s % 86400 / 3600));
    document.getElementById('m').textContent = pad(Math.floor(s % 3600 / 60));
    document.getElementById('s').textContent = pad(s % 60);
  }
  tick();
}
(function () {
  var c = document.getElementById('sky'), x = c.getContext('2d'), w, h, stars, dpr;
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  function initS() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    w = c.width = innerWidth * dpr; h = c.height = innerHeight * dpr;
    c.style.width = innerWidth + 'px'; c.style.height = innerHeight + 'px';
    var n = Math.min(160, Math.floor(innerWidth * innerHeight / 9000));
    stars = [];
    for (var i = 0; i < n; i++) stars.push({ x: Math.random() * w, y: Math.random() * h, r: (Math.random() * 1.3 + 0.3) * dpr, a: Math.random(), sp: Math.random() * 0.02 + 0.004, vy: (Math.random() * 0.12 + 0.02) * dpr });
  }
  function draw() {
    x.clearRect(0, 0, w, h);
    for (var i = 0; i < stars.length; i++) {
      var st = stars[i];
      st.a += st.sp; var tw = 0.5 + Math.abs(Math.sin(st.a)) * 0.5;
      if (!reduce) { st.y += st.vy; if (st.y > h) st.y = 0; }
      x.globalAlpha = tw; x.fillStyle = '#dfe6ff';
      x.beginPath(); x.arc(st.x, st.y, st.r, 0, 6.283); x.fill();
    }
    x.globalAlpha = 1;
    if (!reduce) requestAnimationFrame(draw);
  }
  initS(); draw();
  addEventListener('resize', function () { initS(); if (reduce) draw(); });
})();
</script>
</body>
</html>
GSZM_PUB

echo "==> validating (syntax + render + script parse)"
node --check lib/maintenance.js
node --check routes/adminMaintenance.js
cat > .gszm_v.js <<'GSZM_V'
const ejs = require('ejs'), fs = require('fs');
const pub = ejs.render(fs.readFileSync('views/maintenance.ejs', 'utf8'),
  { logo: '/static/img/logo.png', statusText: 'Scheduled maintenance', title: 't', message: 'm', endTime: '2026-11-02T22:00', whatsapp: '923001234567' },
  { filename: 'views/maintenance.ejs' });
const m = pub.match(/<script>([\s\S]*?)<\/script>/);
if (!m) throw new Error('public view: no script block found');
fs.writeFileSync('/tmp/gszm_script.js', m[1]);
console.log('  public view renders');
ejs.render(fs.readFileSync('views/admin/maintenance.ejs', 'utf8'),
  { s: { maint_on: '0' }, logo: '/static/img/logo.png', flash: null, active: 'maintenance', title: 'Maintenance' },
  { filename: 'views/admin/maintenance.ejs' });
ejs.render(fs.readFileSync('views/admin/maintenance.ejs', 'utf8'),
  { s: { maint_on: '1', maint_logo: 'maint-logo.webp' }, logo: '/static/img/maint-logo.webp', flash: 'x', active: 'maintenance', title: 'Maintenance' },
  { filename: 'views/admin/maintenance.ejs' });
console.log('  admin view renders');
GSZM_V
node .gszm_v.js
node --check /tmp/gszm_script.js
rm -f .gszm_v.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — Maintenance logo uploader added. Open /admin/maintenance and upload your logo."
