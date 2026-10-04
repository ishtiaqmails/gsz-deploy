#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 3: admin dashboard (branding uploads)
#  RUN ON: RETAIL VPS 143.198.209.68  (cd /opt/gsz-deploy && git pull && bash step3.sh)
#  Adds: login-protected /admin with logo + banner upload (device-aware,
#        dimensions shown). Touches ONLY /opt/gsz + pm2 'gsz'. No bot restarts.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP" ] || { echo "ABORT: $APP not found — run step1/step2 first."; exit 1; }
[ -f "$APP/.env" ] || { echo "ABORT: $APP/.env missing."; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}" "${DB_NAME:?}"
echo "== Galaxy Subz x Zayron — Step 3 (admin branding) · port $PORT =="

mkdir -p "$APP/routes" "$APP/views/admin" "$APP/public/img"
ts=$(date +%s)
cp -a "$APP/server.js" "$APP/server.js.bak-step3.$ts"
cp -a "$APP/views/home.ejs" "$APP/views/home.ejs.bak-step3.$ts"

# ---------- admin password (generated once, kept in .env) ----------
if ! grep -q '^ADMIN_PASS=' "$APP/.env"; then
  AP=$(openssl rand -hex 8)
  { echo "ADMIN_USER=admin"; echo "ADMIN_PASS=$AP"; } >> "$APP/.env"
  NEWPASS="$AP"
else
  NEWPASS=""
fi
set -a; . "$APP/.env"; set +a

# ---------- deps ----------
cd "$APP"
npm install --omit=dev --no-audit --no-fund multer@1.4.5-lts.1 >/dev/null 2>&1 || npm install --omit=dev --no-audit --no-fund multer >/dev/null 2>&1
echo "[ok] multer installed"

# ---------- admin router ----------
cat > "$APP/routes/admin.js" <<'GSZ_ADMIN_EOF'
const path = require('path');
const fs = require('fs');
const express = require('express');
const multer = require('multer');

module.exports = function (pool) {
  const router = express.Router();
  const IMG_DIR = path.join(__dirname, '..', 'public', 'img');
  fs.mkdirSync(IMG_DIR, { recursive: true });

  const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, IMG_DIR),
    filename: (req, file, cb) => cb(null, '__upload_' + Date.now() + path.extname(file.originalname || '').toLowerCase())
  });
  const ok = /\.(jpg|jpeg|png|webp|gif|svg)$/i;
  const upload = multer({
    storage,
    limits: { fileSize: 12 * 1024 * 1024 },
    fileFilter: (req, file, cb) => cb(null, ok.test(file.originalname || ''))
  });

  // ---- auth ----
  function auth(req, res, next) {
    if (req.session && req.session.admin) return next();
    return res.redirect('/admin/login');
  }

  router.get('/login', (req, res) => {
    res.render('admin/login', { error: null });
  });
  router.post('/login', express.urlencoded({ extended: false }), (req, res) => {
    const { username, password } = req.body || {};
    if (username === process.env.ADMIN_USER && password === process.env.ADMIN_PASS) {
      req.session.admin = true;
      return res.redirect('/admin');
    }
    res.status(401).render('admin/login', { error: 'Wrong username or password.' });
  });
  router.post('/logout', auth, (req, res) => { req.session.destroy(() => res.redirect('/admin/login')); });

  // ---- dashboard ----
  router.get('/', auth, async (req, res) => {
    const c = (await pool.query('SELECT count(*)::int n FROM categories')).rows[0].n;
    const p = (await pool.query('SELECT count(*)::int n FROM products')).rows[0].n;
    const b = (await pool.query('SELECT count(*)::int n FROM banners')).rows[0].n;
    res.render('admin/dashboard', { counts: { c, p, b }, flash: req.query.ok || null });
  });

  // ---- branding (logo + banners) ----
  const BANNER_SLOTS = [
    { slug: 'entertainment', name: 'Entertainment' },
    { slug: 'iptv', name: 'IPTV services' },
    { slug: 'vpns', name: 'VPNs' },
    { slug: 'tools', name: 'Tools' },
    { slug: 'players', name: 'Player activation' }
  ];
  const DIMS = { desktop: '1942 × 809 px (landscape)', mobile: '1536 × 1024 px (portrait-ish)' };

  router.get('/branding', auth, async (req, res) => {
    const rows = (await pool.query('SELECT category_slug, device, filename FROM banners')).rows;
    const map = {};
    rows.forEach(r => { (map[r.category_slug] = map[r.category_slug] || {})[r.device] = r.filename; });
    const settings = {};
    (await pool.query('SELECT key,value FROM settings')).rows.forEach(r => { settings[r.key] = r.value; });
    res.render('admin/branding', { slots: BANNER_SLOTS, map, dims: DIMS, settings, flash: req.query.ok || null });
  });

  router.post('/branding/logo', auth, upload.single('logo'), async (req, res) => {
    if (!req.file) return res.redirect('/admin/branding?ok=Please+choose+an+image+file');
    const ext = path.extname(req.file.filename).toLowerCase() || '.png';
    const dest = 'logo' + ext;
    fs.renameSync(path.join(IMG_DIR, req.file.filename), path.join(IMG_DIR, dest));
    // remove any other logo.* so only one remains
    fs.readdirSync(IMG_DIR).forEach(f => { if (/^logo\./i.test(f) && f !== dest) { try { fs.unlinkSync(path.join(IMG_DIR, f)); } catch (e) {} } });
    await pool.query(
      'INSERT INTO settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value',
      ['logo_file', dest]
    );
    res.redirect('/admin/branding?ok=Logo+updated');
  });

  router.post('/branding/banner', auth, upload.single('banner'), async (req, res) => {
    const slug = (req.body.category_slug || '').trim();
    const device = req.body.device === 'mobile' ? 'mobile' : 'desktop';
    if (!req.file || !BANNER_SLOTS.some(s => s.slug === slug)) {
      return res.redirect('/admin/branding?ok=Upload+failed+%E2%80%94+check+the+file');
    }
    const ext = path.extname(req.file.filename).toLowerCase() || '.jpg';
    const dest = 'banner-' + slug + '-' + device + '-' + Date.now() + ext;
    fs.renameSync(path.join(IMG_DIR, req.file.filename), path.join(IMG_DIR, dest));
    const existing = (await pool.query(
      'SELECT id, filename FROM banners WHERE category_slug=$1 AND device=$2 ORDER BY id LIMIT 1',
      [slug, device]
    )).rows[0];
    if (existing) {
      await pool.query('UPDATE banners SET filename=$1, active=true WHERE id=$2', [dest, existing.id]);
      if (existing.filename && existing.filename !== dest) {
        try { fs.unlinkSync(path.join(IMG_DIR, existing.filename)); } catch (e) {}
      }
    } else {
      await pool.query(
        'INSERT INTO banners(category_slug, device, filename, active) VALUES($1,$2,$3,true)',
        [slug, device, dest]
      );
    }
    res.redirect('/admin/branding?ok=' + encodeURIComponent(slug + ' ' + device + ' banner updated'));
  });

  return router;
};
GSZ_ADMIN_EOF

# ---------- admin layout partial ----------
cat > "$APP/views/admin/_layout_top.ejs" <<'GSZ_TOP_EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Admin · <%= siteName %></title>
<style>
  :root{color-scheme:light;--bg:#f5f7fc;--ink:#0f1836;--muted:#6b7593;--hair:#e3e8f6;--brand:#2a7bff;--violet:#8a2bff;--ok:#16b765;--surface:#fff}
  *{box-sizing:border-box}
  body{margin:0;font-family:system-ui,'Segoe UI',sans-serif;background:var(--bg);color:var(--ink)}
  a{color:inherit;text-decoration:none}
  .topbar{display:flex;align-items:center;gap:14px;height:60px;padding:0 20px;background:#fff;border-bottom:1px solid var(--hair);position:sticky;top:0;z-index:5}
  .topbar b{font-weight:800;letter-spacing:-.02em}
  .topbar .sp{flex:1}
  .btn{display:inline-flex;align-items:center;gap:8px;font-weight:600;font-size:14px;border-radius:9px;padding:9px 15px;cursor:pointer;border:0}
  .btn-p{background:linear-gradient(118deg,#8a2bff,#2a7bff);color:#fff}
  .btn-g{background:#fff;color:var(--ink);box-shadow:inset 0 0 0 1px var(--hair)}
  .wrap{max-width:1100px;margin:0 auto;padding:24px 20px 60px}
  .nav{display:flex;gap:6px;margin-bottom:22px;flex-wrap:wrap}
  .nav a{padding:8px 14px;border-radius:9px;font-weight:600;font-size:14px;color:var(--muted);background:#fff;box-shadow:inset 0 0 0 1px var(--hair)}
  .nav a.on{background:var(--ink);color:#fff;box-shadow:none}
  h1{font-size:24px;letter-spacing:-.02em;margin:0 0 4px}
  .sub{color:var(--muted);font-size:14px;margin:0 0 22px}
  .card{background:var(--surface);border-radius:14px;box-shadow:0 1px 2px rgba(15,24,54,.05),0 14px 30px -24px rgba(15,24,54,.3);padding:22px;margin-bottom:18px}
  .card h2{font-size:16px;margin:0 0 4px}
  .card .hint{color:var(--muted);font-size:13px;margin:0 0 16px}
  .flash{background:#e9fbf1;color:#0b7a42;border:1px solid #bdebd0;border-radius:10px;padding:11px 14px;font-size:14px;font-weight:600;margin-bottom:18px}
  .grid{display:grid;grid-template-columns:repeat(2,1fr);gap:16px}
  @media(max-width:720px){.grid{grid-template-columns:1fr}}
  .stat{background:#fff;border-radius:12px;box-shadow:inset 0 0 0 1px var(--hair);padding:16px}
  .stat b{font-size:28px;font-weight:800;letter-spacing:-.02em;display:block}
  .stat span{color:var(--muted);font-size:13px}
  .slot{border:1px solid var(--hair);border-radius:12px;padding:14px;margin-bottom:14px}
  .slot h3{font-size:14px;margin:0 0 10px}
  .devrow{display:grid;grid-template-columns:1fr 1fr;gap:14px}
  @media(max-width:620px){.devrow{grid-template-columns:1fr}}
  .dev{border:1px dashed var(--hair);border-radius:10px;padding:12px;background:#fafbff}
  .dev .lbl{font-weight:700;font-size:13px}
  .dev .dim{color:var(--muted);font-size:12px;margin:2px 0 10px}
  .prev{width:100%;aspect-ratio:16/9;object-fit:cover;border-radius:8px;background:#eef2fe;margin-bottom:10px;display:block}
  .none{width:100%;aspect-ratio:16/9;border-radius:8px;background:repeating-linear-gradient(45deg,#eef2fe,#eef2fe 10px,#e3e8f6 10px,#e3e8f6 20px);display:grid;place-items:center;color:var(--muted);font-size:12px;margin-bottom:10px}
  input[type=file]{font-size:13px;width:100%;margin-bottom:10px}
  label.fld{display:block;font-size:13px;font-weight:600;margin-bottom:6px}
  input[type=text],input[type=password]{width:100%;padding:10px 12px;border-radius:9px;border:1px solid var(--hair);font-size:14px;margin-bottom:12px;font-family:inherit}
  .logo-prev{height:52px;margin-bottom:12px}
</style>
</head>
<body>
GSZ_TOP_EOF

# ---------- login ----------
cat > "$APP/views/admin/login.ejs" <<'GSZ_LOGIN_EOF'
<%- include('_layout_top', { siteName: 'Galaxy Subz × Zayron' }) %>
<div class="wrap" style="max-width:380px;margin-top:9vh">
  <h1>Admin sign in</h1>
  <p class="sub">Galaxy Subz × Zayron control panel</p>
  <% if (error) { %><div class="flash" style="background:#fdecec;color:#b42318;border-color:#f6c9c4"><%= error %></div><% } %>
  <form method="post" action="/admin/login" class="card">
    <label class="fld">Username</label>
    <input type="text" name="username" autocomplete="username" autofocus>
    <label class="fld">Password</label>
    <input type="password" name="password" autocomplete="current-password">
    <button class="btn btn-p" type="submit" style="width:100%;justify-content:center">Sign in</button>
  </form>
</div>
</body></html>
GSZ_LOGIN_EOF

# ---------- dashboard ----------
cat > "$APP/views/admin/dashboard.ejs" <<'GSZ_DASH_EOF'
<%- include('_layout_top', { siteName: 'Galaxy Subz × Zayron' }) %>
<div class="topbar"><b>Galaxy Subz × Zayron</b><span style="color:var(--muted);font-size:13px">Admin</span><div class="sp"></div>
  <a class="btn btn-g" href="/" target="_blank">View site ↗</a>
  <form method="post" action="/admin/logout" style="display:inline"><button class="btn btn-g" type="submit">Log out</button></form>
</div>
<div class="wrap">
  <div class="nav"><a class="on" href="/admin">Dashboard</a><a href="/admin/branding">Branding &amp; Banners</a></div>
  <h1>Dashboard</h1>
  <p class="sub">Manage what shows on your storefront.</p>
  <% if (flash) { %><div class="flash"><%= flash %></div><% } %>
  <div class="grid">
    <div class="stat"><b><%= counts.c %></b><span>Categories</span></div>
    <div class="stat"><b><%= counts.p %></b><span>Products</span></div>
    <div class="stat"><b><%= counts.b %></b><span>Banner slots</span></div>
    <div class="stat"><b>Live</b><span>Site status</span></div>
  </div>
  <div class="card" style="margin-top:18px">
    <h2>Branding &amp; Banners</h2>
    <p class="hint">Upload your logo and the hero banners (desktop + mobile per category). Changes appear on the live site immediately.</p>
    <a class="btn btn-p" href="/admin/branding">Open Branding &amp; Banners</a>
  </div>
</div>
</body></html>
GSZ_DASH_EOF

# ---------- branding ----------
cat > "$APP/views/admin/branding.ejs" <<'GSZ_BRAND_EOF'
<%- include('_layout_top', { siteName: 'Galaxy Subz × Zayron' }) %>
<div class="topbar"><b>Galaxy Subz × Zayron</b><span style="color:var(--muted);font-size:13px">Admin</span><div class="sp"></div>
  <a class="btn btn-g" href="/" target="_blank">View site ↗</a>
  <form method="post" action="/admin/logout" style="display:inline"><button class="btn btn-g" type="submit">Log out</button></form>
</div>
<div class="wrap">
  <div class="nav"><a href="/admin">Dashboard</a><a class="on" href="/admin/branding">Branding &amp; Banners</a></div>
  <h1>Branding &amp; Banners</h1>
  <p class="sub">Upload your real logo and hero banners. Each slot shows the exact size to use.</p>
  <% if (flash) { %><div class="flash"><%= flash %></div><% } %>

  <div class="card">
    <h2>Logo</h2>
    <p class="hint">Transparent PNG or SVG works best. Shown in the header and footer.</p>
    <% var lf = settings.logo_file || 'logo.png'; %>
    <img class="logo-prev" src="/static/img/<%= lf %>?v=<%= Date.now() %>" alt="Current logo" onerror="this.style.display='none'">
    <form method="post" action="/admin/branding/logo" enctype="multipart/form-data">
      <input type="file" name="logo" accept="image/*" required>
      <button class="btn btn-p" type="submit">Upload logo</button>
    </form>
  </div>

  <div class="card">
    <h2>Hero banners</h2>
    <p class="hint">Each category has a <b>desktop</b> and a <b>mobile</b> banner. The site automatically shows the right one per device.</p>
    <% slots.forEach(function(s){ var cur = map[s.slug] || {}; %>
      <div class="slot">
        <h3><%= s.name %></h3>
        <div class="devrow">
          <% ['desktop','mobile'].forEach(function(dev){ %>
            <div class="dev">
              <div class="lbl"><%= dev.charAt(0).toUpperCase()+dev.slice(1) %></div>
              <div class="dim">Required size: <%= dims[dev] %></div>
              <% if (cur[dev]) { %>
                <img class="prev" src="/static/img/<%= cur[dev] %>?v=<%= Date.now() %>" alt="">
              <% } else { %>
                <div class="none">No banner yet</div>
              <% } %>
              <form method="post" action="/admin/branding/banner" enctype="multipart/form-data">
                <input type="hidden" name="category_slug" value="<%= s.slug %>">
                <input type="hidden" name="device" value="<%= dev %>">
                <input type="file" name="banner" accept="image/*" required>
                <button class="btn btn-p" type="submit" style="width:100%;justify-content:center"><%= cur[dev] ? 'Replace' : 'Upload' %></button>
              </form>
            </div>
          <% }); %>
        </div>
      </div>
    <% }); %>
  </div>
</div>
</body></html>
GSZ_BRAND_EOF

# ---------- server.js (rewrite: mount admin + pass logoFile to home) ----------
cat > "$APP/server.js" <<'GSZ_SRV3_EOF'
require('dotenv').config();
const path = require('path');
const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const session = require('express-session');
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  max: 10
});

const app = express();
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
app.use(compression());
app.use(morgan('tiny'));
app.use('/static', express.static(path.join(__dirname, 'public'), { maxAge: '7d' }));
app.use(session({ secret: process.env.SESSION_SECRET, resave: false, saveUninitialized: false }));

async function homeData() {
  const cats = (await pool.query(
    'SELECT slug, name, tag, glyph FROM categories WHERE active ORDER BY sort, id'
  )).rows;
  const products = (await pool.query(
    `SELECT p.slug, c.slug AS cat, p.name, p.short_desc AS desc, p.delivery,
            pl.label AS plan, pl.price_pkr AS price, pl.old_pkr AS old
     FROM products p
     JOIN categories c ON c.id = p.category_id
     LEFT JOIN LATERAL (
       SELECT label, price_pkr, old_pkr FROM product_plans
       WHERE product_id = p.id ORDER BY sort, id LIMIT 1
     ) pl ON true
     WHERE p.active AND NOT p.hidden
     ORDER BY p.sort, p.id`
  )).rows.map(r => ({
    slug: r.slug, cat: r.cat, name: r.name, plan: r.plan || '',
    price: Number(r.price || 0), old: Number(r.old || 0),
    desc: r.desc || '', delivery: r.delivery || ''
  }));
  const banners = (await pool.query(
    'SELECT category_slug, device, filename, title FROM banners WHERE active ORDER BY sort, id'
  )).rows;
  const reviews = (await pool.query(
    'SELECT author, location, stars, body FROM reviews WHERE approved ORDER BY id DESC LIMIT 12'
  )).rows;
  const settings = {};
  (await pool.query('SELECT key, value FROM settings')).rows.forEach(r => { settings[r.key] = r.value; });
  return { cats, products, banners, reviews, settings };
}

app.get('/health', async (req, res) => {
  try {
    const c = await pool.query('SELECT count(*)::int AS n FROM categories');
    const p = await pool.query('SELECT count(*)::int AS n FROM products');
    const b = await pool.query('SELECT count(*)::int AS n FROM banners');
    res.json({ ok: true, categories: c.rows[0].n, products: p.rows[0].n, banners: b.rows[0].n });
  } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
});

// Admin
const adminRouter = require('./routes/admin')(pool);
app.use('/admin', adminRouter);

app.get('/', async (req, res) => {
  try {
    const data = await homeData();
    const siteName = data.settings.site_name || 'Galaxy Subz × Zayron';
    const logoFile = data.settings.logo_file || 'logo.png';
    const dataJson = JSON.stringify(data).replace(/</g, '\\u003c');
    res.render('home', { siteName, logoFile, dataJson });
  } catch (e) {
    res.status(500).send('Home render error: ' + e.message);
  }
});

const PORT = process.env.PORT || 3600;
app.listen(PORT, '0.0.0.0', () => console.log('[gsz] listening on ' + PORT));
GSZ_SRV3_EOF

# ---------- patch home.ejs: use <%= logoFile %> instead of hardcoded logo.png ----------
node -e '
const fs=require("fs");const f="'"$APP"'/views/home.ejs";let s=fs.readFileSync(f,"utf8");
const before=(s.match(/\/static\/img\/logo\.png/g)||[]).length;
s=s.split("/static/img/logo.png").join("/static/img/<%= logoFile %>");
fs.writeFileSync(f,s);
console.log("[ok] home.ejs logo refs rewired: "+before);
'

# ---------- validate ----------
node --check "$APP/server.js"
node --check "$APP/routes/admin.js"
echo "[ok] server.js + admin.js parse clean"

pm2 restart gsz --update-env >/dev/null
sleep 1.6

HOME=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
LOGIN=$(curl -fsS "http://127.0.0.1:$PORT/admin/login" || true)
if echo "$HOME" | grep -q "window.__DATA" && echo "$LOGIN" | grep -q "Admin sign in"; then
  echo "[ok] homepage still renders + admin login page live"
else
  echo "CHECK FAILED — rolling back"
  cp -a "$APP/server.js.bak-step3.$ts" "$APP/server.js"
  cp -a "$APP/views/home.ejs.bak-step3.$ts" "$APP/views/home.ejs"
  pm2 restart gsz >/dev/null; pm2 logs gsz --lines 25 --nostream || true; exit 1
fi

echo "============================================================"
echo " STEP 3 COMPLETE — admin dashboard is live"
echo "   admin:  http://143.198.209.68:$PORT/admin"
if [ -n "$NEWPASS" ]; then
echo "   login:  username  admin"
echo "           password  $NEWPASS"
echo "   (saved in $APP/.env — change ADMIN_PASS there anytime, then: pm2 restart gsz --update-env)"
else
echo "   login:  use your existing admin credentials (in $APP/.env)"
fi
echo "   Upload your logo + banners under 'Branding & Banners'."
echo "============================================================"
