#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 4: product detail pages
#  RUN: cd /opt/gsz-deploy && git pull && bash step4.sh
#  Adds: /product/:slug page (image, short/long desc, plans+pricing,
#        FAQ, Order on WhatsApp prefilled, similar products) and makes
#        every homepage card a real link. Touches ONLY /opt/gsz + pm2 'gsz'.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP" ] || { echo "ABORT: $APP not found — run earlier steps first."; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}" "${DB_NAME:?}" "${DB_USER:?}"
echo "== Galaxy Subz x Zayron — Step 4 (product pages) · port $PORT =="

ts=$(date +%s)
cp -a "$APP/server.js" "$APP/server.js.bak-step4.$ts"
cp -a "$APP/public/js/app.js" "$APP/public/js/app.js.bak-step4.$ts"

# ---------- 1. schema additions (idempotent) ----------
PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 <<'GSZ_SQL_EOF'
ALTER TABLE products ADD COLUMN IF NOT EXISTS long_desc text;
CREATE TABLE IF NOT EXISTS product_faqs (
  id serial PRIMARY KEY,
  product_id int NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  q text NOT NULL,
  a text NOT NULL,
  sort int NOT NULL DEFAULT 0
);
GSZ_SQL_EOF
echo "[ok] schema ready (long_desc + product_faqs)"

# ---------- 2. products route ----------
cat > "$APP/routes/products.js" <<'GSZ_PR_EOF'
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();

  // stable pseudo-random from an integer (so rating/orders don't flicker)
  function seeded(n) { const x = Math.sin(n * 99.17) * 10000; return x - Math.floor(x); }

  router.get('/:slug', async (req, res) => {
    try {
      const prow = (await pool.query(
        `SELECT p.id, p.slug, p.name, p.short_desc, p.long_desc, p.delivery,
                c.slug AS cat_slug, c.name AS cat_name, c.tag AS cat_tag
         FROM products p JOIN categories c ON c.id = p.category_id
         WHERE p.slug = $1 AND p.active AND NOT p.hidden`, [req.params.slug]
      )).rows[0];
      if (!prow) return res.status(404).render('notfound', { what: 'product' });

      const plans = (await pool.query(
        'SELECT label, price_pkr, old_pkr FROM product_plans WHERE product_id=$1 ORDER BY sort, id', [prow.id]
      )).rows.map(r => ({ label: r.label, price: Number(r.price_pkr || 0), old: Number(r.old_pkr || 0) }));

      const faqs = (await pool.query(
        'SELECT q, a FROM product_faqs WHERE product_id=$1 ORDER BY sort, id', [prow.id]
      )).rows;

      const similar = (await pool.query(
        `SELECT p.slug, p.name, p.short_desc AS desc, p.delivery, c.slug AS cat, c.tag AS cat_tag,
                pl.label AS plan, pl.price_pkr AS price, pl.old_pkr AS old
         FROM products p JOIN categories c ON c.id = p.category_id
         LEFT JOIN LATERAL (SELECT label, price_pkr, old_pkr FROM product_plans WHERE product_id=p.id ORDER BY sort, id LIMIT 1) pl ON true
         WHERE c.id = (SELECT category_id FROM products WHERE id=$1) AND p.id <> $1 AND p.active AND NOT p.hidden
         ORDER BY p.sort, p.id LIMIT 8`, [prow.id]
      )).rows.map(r => ({ slug: r.slug, name: r.name, cat: r.cat, cat_tag: r.cat_tag, plan: r.plan || '',
        desc: r.desc || '', delivery: r.delivery || '', price: Number(r.price || 0), old: Number(r.old || 0) }));

      const settings = {};
      (await pool.query('SELECT key,value FROM settings')).rows.forEach(r => { settings[r.key] = r.value; });

      const rating = (4.5 + seeded(prow.id) * 0.5).toFixed(1);
      const orders = 200 + Math.floor(seeded(prow.id + 7) * 9800);

      res.render('product', {
        p: prow, plans, faqs, similar, settings,
        logoFile: settings.logo_file || 'logo.png',
        waNumber: settings.wa_number || process.env.WA_NUMBER || '',
        rating, orders
      });
    } catch (e) {
      res.status(500).send('Product error: ' + e.message);
    }
  });

  return router;
};
GSZ_PR_EOF
echo "[ok] routes/products.js written"

# ---------- 3. notfound view ----------
cat > "$APP/views/notfound.ejs" <<'GSZ_NF_EOF'
<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Not found</title>
<style>body{margin:0;font-family:system-ui,sans-serif;background:#f6f8ff;color:#0a0f24;display:grid;place-items:center;min-height:100vh;text-align:center}
a{color:#2a7bff}</style></head><body><div><h1>We couldn't find that <%= what %>.</h1>
<p><a href="/">← Back to the store</a></p></div></body></html>
GSZ_NF_EOF

# ---------- 4. product view ----------
cat > "$APP/views/product.ejs" <<'GSZ_PV_EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title><%= p.name %> · <%= settings.site_name || 'Galaxy Subz × Zayron' %></title>
<link rel="icon" href="/static/img/<%= logoFile %>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Schibsted+Grotesk:wght@400;500;600;700;800&family=Hanken+Grotesk:wght@400;500;600;700&display=swap">
<link rel="stylesheet" href="/static/css/app.css">
<style>
  .pwrap{max-width:1100px;margin:0 auto;padding-inline:var(--gutter)}
  .crumb{display:flex;gap:8px;align-items:center;color:var(--muted);font-size:13px;padding:18px 0;font-family:var(--display);font-weight:600}
  .crumb a{color:var(--muted)}.crumb a:hover{color:var(--azure)}
  .ptop{display:grid;grid-template-columns:1fr 1fr;gap:34px;align-items:start}
  @media(max-width:820px){.ptop{grid-template-columns:1fr;gap:22px}}
  .phero{position:relative;aspect-ratio:16/11;border-radius:var(--r-lg);overflow:hidden;
    background:radial-gradient(130% 100% at 24% -10%,var(--g1),transparent 56%),linear-gradient(162deg,#111735,#090c1e);
    display:flex;flex-direction:column;justify-content:flex-end;padding:26px;box-shadow:var(--shadow-card)}
  .phero:before{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(255,255,255,.16),transparent 38%)}
  .phero .cat-mini{position:absolute;top:18px;left:20px;z-index:2;font-family:var(--display);font-weight:600;font-size:11px;letter-spacing:.09em;text-transform:uppercase;color:rgba(255,255,255,.65)}
  .phero .wm{position:absolute;top:18px;right:20px;z-index:2;font-family:var(--display);font-weight:800;font-size:12px;color:rgba(255,255,255,.5)}
  .phero .pn{position:relative;z-index:2;font-family:var(--display);font-weight:800;font-size:34px;line-height:1.02;letter-spacing:-.02em;
    background:linear-gradient(180deg,#fff,#c3d0ea);-webkit-background-clip:text;background-clip:text;color:transparent}
  .pinfo h1{font-size:clamp(26px,3.4vw,38px);margin:0 0 8px}
  .pmeta{display:flex;align-items:center;gap:14px;flex-wrap:wrap;color:var(--muted);font-size:13.5px;margin-bottom:16px;font-weight:500}
  .pmeta .stars{color:#f5a623;letter-spacing:1px}
  .pmeta .d{width:5px;height:5px;border-radius:50%;background:var(--positive);display:inline-block}
  .plead{font-size:16px;color:var(--ink-2);line-height:1.55;margin-bottom:22px;max-width:60ch}
  .plans{display:flex;flex-direction:column;gap:10px;margin-bottom:20px}
  .plan-opt{display:flex;align-items:center;gap:14px;border:1.5px solid var(--hair-2);border-radius:12px;padding:14px 16px;cursor:pointer;transition:.18s;background:#fff}
  .plan-opt:hover{border-color:var(--azure)}
  .plan-opt.sel{border-color:var(--azure);box-shadow:0 0 0 3px rgba(26,95,240,.12)}
  .plan-opt .rdo{width:20px;height:20px;border-radius:50%;border:2px solid var(--hair-2);flex:none;display:grid;place-items:center}
  .plan-opt.sel .rdo{border-color:var(--azure)}
  .plan-opt.sel .rdo:after{content:"";width:10px;height:10px;border-radius:50%;background:var(--azure)}
  .plan-opt .pl-label{font-family:var(--display);font-weight:600;font-size:15px;flex:1}
  .plan-opt .pl-price{font-family:var(--display);font-weight:800;font-size:18px}
  .plan-opt .pl-price .was{font-size:12.5px;color:var(--muted);text-decoration:line-through;font-weight:500;margin-right:6px}
  .buyrow{display:flex;flex-direction:column;gap:10px;margin-bottom:18px}
  .buyrow .btn{justify-content:center;font-size:15px;padding:15px}
  .trustgrid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:8px}
  .tb{display:flex;align-items:center;gap:9px;font-size:13px;color:var(--ink-2);font-weight:500}
  .tb svg{color:var(--azure)}
  .psec{padding-block:clamp(30px,4vw,52px)}
  .psec h2{font-size:22px;margin:0 0 16px}
  .longdesc{font-size:15.5px;line-height:1.7;color:var(--ink-2);max-width:70ch;white-space:pre-line}
  .faq{border-top:1px solid var(--hair)}
  .faq details{border-bottom:1px solid var(--hair);padding:4px 0}
  .faq summary{cursor:pointer;list-style:none;padding:15px 0;font-family:var(--display);font-weight:600;font-size:15px;display:flex;justify-content:space-between;gap:12px}
  .faq summary::-webkit-details-marker{display:none}
  .faq summary:after{content:"+";color:var(--azure);font-weight:700}
  .faq details[open] summary:after{content:"–"}
  .faq p{margin:0 0 15px;color:var(--ink-2);font-size:14.5px;line-height:1.6;max-width:68ch}
</style>
</head>
<body>
<canvas id="aura" aria-hidden="true"></canvas>
<div class="topline"></div>

<header class="hd">
  <div class="wrap hd-in">
    <a href="/" class="brand" aria-label="Home"><img src="/static/img/<%= logoFile %>" alt="Galaxy Subz x Zayron" onerror="this.style.display='none';this.nextElementSibling.style.display='inline-flex'"><span class="logofall" style="display:none;align-items:center;gap:6px;font-family:var(--display);font-weight:800;font-size:20px">Galaxy Subz&nbsp;<span style="background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent">× Zayron</span></span></a>
    <div class="hd-sp"></div>
    <div class="hd-tools">
      <a class="btn btn-ghost" href="/">← All products</a>
    </div>
  </div>
</header>

<div class="pwrap">
  <div class="crumb"><a href="/">Home</a> › <a href="/#cat-<%= p.cat_slug %>"><%= p.cat_name %></a> › <span style="color:var(--ink)"><%= p.name %></span></div>

  <div class="ptop">
    <div class="phero" style="--g1:#2a7bff">
      <span class="cat-mini"><%= p.cat_tag %></span><span class="wm">GS×ZD</span>
      <span class="pn"><%= p.name %></span>
    </div>
    <div class="pinfo">
      <h1><%= p.name %></h1>
      <div class="pmeta">
        <span class="stars">★★★★★</span>
        <span><b style="color:var(--ink)"><%= rating %></b> rating</span>
        <span><span class="d"></span> <%= orders.toLocaleString('en-US') %>+ orders</span>
        <span><%= p.delivery %></span>
      </div>
      <p class="plead"><%= p.short_desc %>.</p>

      <div class="plans" id="plans">
        <% plans.forEach(function(pl, i){ %>
          <div class="plan-opt<%= i===0?' sel':'' %>" data-price="<%= pl.price %>" data-old="<%= pl.old %>" data-label="<%= pl.label %>">
            <span class="rdo"></span>
            <span class="pl-label"><%= pl.label %></span>
            <span class="pl-price"><% if (pl.old>0){ %><span class="was" data-oldpkr="<%= pl.old %>"></span><% } %><span class="now" data-pkr="<%= pl.price %>"></span></span>
          </div>
        <% }); %>
      </div>

      <div class="buyrow">
        <a class="btn btn-wa" id="waBtn" href="#" target="_blank" rel="noopener">
          <svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>
          Order on WhatsApp
        </a>
        <a class="btn btn-primary" id="buyBtn" href="#" target="_blank" rel="noopener">Buy now</a>
      </div>

      <div class="trustgrid">
        <div class="tb"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/></svg> Instant delivery</div>
        <div class="tb"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/></svg> Verified payments</div>
        <div class="tb"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M4 4h16v12H5l-1 2V4Z"/></svg> Email &amp; PDF invoice</div>
        <div class="tb"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M4 12a8 8 0 0 1 16 0v4a3 3 0 0 1-3 3h-2v-5h5"/></svg> 24/7 WhatsApp support</div>
      </div>
    </div>
  </div>

  <% if (p.long_desc && p.long_desc.trim()) { %>
  <section class="psec"><h2>About <%= p.name %></h2><div class="longdesc"><%= p.long_desc %></div></section>
  <% } %>

  <% if (faqs.length) { %>
  <section class="psec"><h2>Frequently asked questions</h2>
    <div class="faq">
      <% faqs.forEach(function(f){ %><details><summary><%= f.q %></summary><p><%= f.a %></p></details><% }); %>
    </div>
  </section>
  <% } %>
</div>

<% if (similar.length) { %>
<section class="section sec-alt">
  <div class="wrap">
    <div class="sec-head"><div class="lead"><span class="cat-tag grad-text"><span class="dot" style="background:var(--brand)"></span>You may also like</span><h2>Similar in <%= p.cat_name %></h2></div>
      <a class="view-all" href="/#cat-<%= p.cat_slug %>">View all</a></div>
    <div class="rail" id="simRail"></div>
  </div>
</section>
<% } %>

<footer class="ft"><div class="wrap"><div class="ft-bottom" style="border:0">
  <span class="copy">© 2026 <%= settings.site_name || 'Galaxy Subz × Zayron' %>. All rights reserved.</span>
  <a class="copy" href="/" style="color:var(--cyan)">← Back to store</a>
</div></div></footer>

<script>
var WA = <%- JSON.stringify(waNumber) %>;
var PNAME = <%- JSON.stringify(p.name) %>;
var SIM = <%- JSON.stringify(similar) %>;
var COLOR={entertainment:'#6a46ff',sports:'#18b0a0',iptv:'#2a7bff',vpns:'#3f73c9',tools:'#9a3bff',zoom:'#2e86f0',players:'#17cbf0',profiles:'#19b6e8',smm:'#c23bff'};
var REGIONS={PK:{cur:'Rs',rate:1},US:{cur:'$',rate:0.0036},GB:{cur:'£',rate:0.0028},AE:{cur:'AED',rate:0.013}};
var REG='PK'; try{var r=localStorage.getItem('gsz_region');if(r&&REGIONS[r])REG=r}catch(e){}
function money(pkr){var x=REGIONS[REG];if(x.cur==='Rs')return 'Rs '+Math.round(pkr).toLocaleString('en-US');var v=pkr*x.rate;return x.cur+' '+(v<10?v.toFixed(2):Math.round(v).toLocaleString('en-US'))}
function paint(){document.querySelectorAll('[data-pkr]').forEach(function(el){el.textContent=money(+el.dataset.pkr)});document.querySelectorAll('[data-oldpkr]').forEach(function(el){el.textContent=money(+el.dataset.oldpkr)})}
var sel=null;
function pickFirst(){sel=document.querySelector('.plan-opt.sel')||document.querySelector('.plan-opt');updateCTA()}
function updateCTA(){if(!sel)return;var label=sel.dataset.label,price=money(+sel.dataset.price);
  var msg='Hi! I want to order *'+PNAME+'* — '+label+' ('+price+').';
  var href=WA?('https://wa.me/'+WA.replace(/[^0-9]/g,'')+'?text='+encodeURIComponent(msg)):'#';
  document.getElementById('waBtn').href=href;document.getElementById('buyBtn').href=href;}
document.getElementById('plans').addEventListener('click',function(e){var o=e.target.closest('.plan-opt');if(!o)return;
  document.querySelectorAll('.plan-opt').forEach(function(x){x.classList.remove('sel')});o.classList.add('sel');sel=o;updateCTA()});
paint();pickFirst();

// similar rail (reuse card look)
function simCard(p){var g=COLOR[p.cat]||'#2a7bff';var was=p.old>0?('<span class="was tnum" data-oldpkr="'+p.old+'"></span> '):'';
  return '<a class="card" href="/product/'+p.slug+'">'
    +'<div class="thumb"><div class="tile" style="--g1:'+g+'"><span class="cat-mini">'+p.cat_tag+'</span><span class="wm">GS×ZD</span><span class="pname">'+p.name+'</span></div></div>'
    +'<div class="body"><div class="meta"><span class="d"></span>'+p.delivery+'</div><span class="plan">'+(p.plan||'')+'</span>'
    +'<p class="pdesc">'+p.desc+'.</p><div class="foot"><div class="price">'+was+'<span class="now tnum" data-pkr="'+p.price+'"></span></div>'
    +'<span class="buy"><svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M5 12h14M13 6l6 6-6 6"/></svg></span></div></div></a>'}
var sr=document.getElementById('simRail');if(sr){sr.innerHTML=SIM.map(simCard).join('');paint();}

// brand aurora (same as home, lightweight)
(function(){var cv=document.getElementById('aura');if(!cv)return;var ctx=cv.getContext('2d');var w,h,raf;
 var blobs=[{c:'138,43,255'},{c:'42,123,255'},{c:'23,203,240'}].map(function(b,i){return {c:b.c,x:Math.random(),y:Math.random()*.5,vx:(Math.random()-.5)*.00016,vy:(Math.random()-.5)*.00012,ph:i}});
 function size(){w=cv.width=innerWidth;h=cv.height=Math.min(innerHeight,900);cv.style.height=h+'px'}
 function draw(t){ctx.clearRect(0,0,w,h);ctx.globalCompositeOperation='lighter';blobs.forEach(function(b){b.x+=b.vx;b.y+=b.vy;if(b.x<-.1||b.x>1.1)b.vx*=-1;if(b.y<-.1||b.y>.7)b.vy*=-1;var cx=b.x*w,cy=b.y*h+Math.sin(t/4000+b.ph)*16,rad=Math.max(w,h)*.4;var g=ctx.createRadialGradient(cx,cy,0,cx,cy,rad);g.addColorStop(0,'rgba('+b.c+',.16)');g.addColorStop(1,'rgba('+b.c+',0)');ctx.fillStyle=g;ctx.beginPath();ctx.arc(cx,cy,rad,0,7);ctx.fill()});raf=requestAnimationFrame(draw)}
 size();addEventListener('resize',size);if(matchMedia('(prefers-reduced-motion:reduce)').matches){draw(0);return}raf=requestAnimationFrame(draw)})();
</script>
</body>
</html>
GSZ_PV_EOF
echo "[ok] views/product.ejs + notfound.ejs written"

# ---------- 5. patch app.js: add slug, make cards links, stop card toast ----------
node <<'GSZ_PATCH_EOF'
const fs=require('fs');const f='/opt/gsz/public/js/app.js';let s=fs.readFileSync(f,'utf8');let n=0;
function rep(a,b){ if(s.includes(a)){ s=s.split(a).join(b); n++; } else { console.log('WARN anchor not found: '+a.slice(0,40)); } }
// 1) carry slug through
rep('.map(p=>({cat:p.cat,name:p.name,', '.map(p=>({cat:p.cat,slug:p.slug,name:p.name,');
// 2) card becomes a link
rep('return `<article class="card" data-name="${p.name}" data-plan="${p.plan}">',
    'return `<a class="card" href="/product/${p.slug}" data-name="${p.name}" data-plan="${p.plan}">');
rep('    </div></article>`}', '    </div></a>`}');
// 3) only feat cards toast; real cards navigate natively
rep(".querySelectorAll('.card[data-name],.feat[data-name]')", ".querySelectorAll('.feat[data-name]')");
fs.writeFileSync(f,s);
console.log('[ok] app.js patches applied: '+n+'/4');
if(n<4){process.exit(1)}
GSZ_PATCH_EOF

# ---------- 6. server.js (mount products route) ----------
cat > "$APP/server.js" <<'GSZ_SRV4_EOF'
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

const adminRouter = require('./routes/admin')(pool);
app.use('/admin', adminRouter);

const productsRouter = require('./routes/products')(pool);
app.use('/product', productsRouter);

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
GSZ_SRV4_EOF

# ---------- 7. validate ----------
node --check "$APP/server.js"
node --check "$APP/routes/products.js"
node --check "$APP/public/js/app.js"
echo "[ok] server.js + products.js + app.js parse clean"

pm2 restart gsz --update-env >/dev/null
sleep 1.6

SLUG=$(PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT slug FROM products ORDER BY sort,id LIMIT 1" | tr -d '[:space:]')
HOME=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
PP=$(curl -fsS "http://127.0.0.1:$PORT/product/$SLUG" || true)
if echo "$HOME" | grep -q "window.__DATA" && echo "$PP" | grep -q "Order on WhatsApp" && echo "$PP" | grep -q "/product/"; then
  echo "[ok] homepage + product page both render (tested /product/$SLUG)"
else
  echo "CHECK FAILED — rolling back"
  cp -a "$APP/server.js.bak-step4.$ts" "$APP/server.js"
  cp -a "$APP/public/js/app.js.bak-step4.$ts" "$APP/public/js/app.js"
  pm2 restart gsz >/dev/null; pm2 logs gsz --lines 25 --nostream || true; exit 1
fi

echo "============================================================"
echo " STEP 4 COMPLETE — product pages live, cards are clickable"
echo "   try:  http://143.198.209.68:$PORT/product/$SLUG"
echo "   (click any product card on the homepage — opens its page;"
echo "    pick a plan → Order on WhatsApp is prefilled with product+plan+price)"
echo "============================================================"
