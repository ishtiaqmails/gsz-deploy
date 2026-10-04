#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 9: storefront redesign
#  RUN: cd /opt/gsz-deploy && git pull && bash step9.sh
#  New art direction: universal header + live search, full-bleed hero,
#  image-led product cards ("Starts from"), curated non-repetitive
#  sections, category pages, lighter surfaces, bigger type.
#  Rewrites: server.js, home view, app.css, app.js. Adds: storefront
#  lib, category route+view, shared store header/footer partials.
#  No changes to admin, orders, checkout, pricing or product data.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views" ] || { echo "ABORT: $APP/views not found — run earlier steps first."; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"; : "${DB_USER:?}"; : "${DB_NAME:?}"; : "${DB_PASS:?}"
echo "== Galaxy Subz x Zayron — Step 9 (storefront redesign) · port $PORT =="
ts=$(date +%s)
PSQL(){ PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" "$@"; }
mkdir -p "$APP/lib" "$APP/views/partials"

# backups of files we REPLACE
cp -a "$APP/server.js"            "$APP/server.js.bak-step9.$ts"
cp -a "$APP/views/home.ejs"       "$APP/views/home.ejs.bak-step9.$ts"
cp -a "$APP/public/css/app.css"   "$APP/public/css/app.css.bak-step9.$ts"
cp -a "$APP/public/js/app.js"     "$APP/public/js/app.js.bak-step9.$ts"

restore(){
  echo ">> rolling back Step 9"
  cp -a "$APP/server.js.bak-step9.$ts"          "$APP/server.js"
  cp -a "$APP/views/home.ejs.bak-step9.$ts"     "$APP/views/home.ejs"
  cp -a "$APP/public/css/app.css.bak-step9.$ts" "$APP/public/css/app.css"
  cp -a "$APP/public/js/app.js.bak-step9.$ts"   "$APP/public/js/app.js"
  rm -f "$APP/lib/storefront.js" "$APP/routes/category.js" \
        "$APP/views/category.ejs" "$APP/views/partials/store_top.ejs" "$APP/views/partials/store_bottom.ejs"
  pm2 restart gsz >/dev/null 2>&1 || true
}

cat > "$APP/lib/storefront.js" <<'GSZ_LIB_EOF'
/* Shared storefront data helpers — used by the home route and the
   category router so cards, categories and search behave identically. */
const ICON = {
  tv:'<rect x="3" y="5" width="18" height="12" rx="2"/><path d="M8 21h8M12 17v4"/>',
  film:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 4v16M17 4v16M3 9h4M3 15h4M17 9h4M17 15h4"/>',
  shield:'<path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/>',
  bolt:'<path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/>',
  play:'<circle cx="12" cy="12" r="9"/><path d="m10 9 5 3-5 3Z"/>',
  grid:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  globe:'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>',
  sparkles:'<path d="M12 3l1.8 4.9L19 10l-5.2 2.1L12 17l-1.8-4.9L5 10l5.2-2.1L12 3Z"/>',
  ball:'<circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 0 0 18M3 12h18"/>'
};
const ACCENT = {
  entertainment:['#7a2bff','#c23bff'], iptv:['#2a6cff','#19c6ee'], sports:['#12b26a','#19c6ee'],
  vpns:['#2a6cff','#5b8bff'], tools:['#7a2bff','#2a6cff'], zoom:['#2a6cff','#19c6ee'],
  players:['#19c6ee','#2a6cff'], profiles:['#7a2bff','#19c6ee'], smm:['#c23bff','#7a2bff']
};
function iconFor(g){ return ICON[g] || ICON.grid; }

async function loadCats(pool){
  const rows = (await pool.query(
    `SELECT slug,name,tag,glyph,id,
            (SELECT count(*) FROM products p WHERE p.category_id=categories.id AND p.active AND NOT p.hidden)::int n
     FROM categories WHERE active ORDER BY sort,id`)).rows;
  return rows.map(c => { const a = ACCENT[c.slug] || ['#2a6cff','#19c6ee'];
    return { slug:c.slug, name:c.name, tag:c.tag||'', n:c.n, id:c.id, g1:a[0], g2:a[1], icon:iconFor(c.glyph) }; });
}
async function loadProducts(pool, catId){
  const where = catId ? 'AND p.category_id=$1' : '';
  const params = catId ? [catId] : [];
  const rows = (await pool.query(
    `SELECT p.slug, c.slug AS cat, c.name AS catname, p.name, p.short_desc AS descr, p.image,
            (SELECT MIN(price_pkr) FROM product_plans WHERE product_id=p.id) AS from_price,
            (SELECT COUNT(*) FROM product_plans WHERE product_id=p.id)::int AS plan_count
     FROM products p JOIN categories c ON c.id=p.category_id
     WHERE p.active AND NOT p.hidden ${where} ORDER BY p.sort,p.id`, params)).rows;
  return rows.map(r => ({ slug:r.slug, cat:r.cat, catName:r.catname, name:r.name,
    descr:r.descr||'', image:r.image||'', from:Number(r.from_price||0), plans:r.plan_count||0 }));
}
async function loadSettings(pool){
  const s = {};
  (await pool.query('SELECT key,value FROM settings')).rows.forEach(r => { s[r.key] = r.value; });
  return s;
}
async function loadBannerMap(pool){
  const m = {};
  (await pool.query('SELECT category_slug,device,filename FROM banners WHERE active')).rows
    .forEach(b => { (m[b.category_slug] = m[b.category_slug] || {})[b.device] = b.filename; });
  return m;
}
function shellJson(cats, products, settings, wa){
  const compact = products.map(p => ({ slug:p.slug, name:p.name, cat:p.cat, catName:p.catName, image:p.image, from:p.from, plans:p.plans }));
  const c = cats.map(x => ({ slug:x.slug, name:x.name, tag:x.tag, n:x.n, g1:x.g1, g2:x.g2, icon:x.icon }));
  return JSON.stringify({ cats:c, products:compact, settings:{ rating:settings.rating, delivered:settings.delivered }, wa:wa||'' }).replace(/</g,'\\u003c');
}
module.exports = { loadCats, loadProducts, loadSettings, loadBannerMap, shellJson, iconFor };
GSZ_LIB_EOF

cat > "$APP/routes/category.js" <<'GSZ_CATR_EOF'
const express = require('express');
const storefront = require('../lib/storefront');

module.exports = function (pool) {
  const router = express.Router();

  router.get('/:slug', async (req, res) => {
    try {
      const cats = await storefront.loadCats(pool);
      const cat = cats.filter(c => c.slug === req.params.slug)[0];
      if (!cat) return res.status(404).render('notfound', { what: 'category' });
      const products = await storefront.loadProducts(pool, cat.id);
      const allProducts = await storefront.loadProducts(pool);
      const settings = await storefront.loadSettings(pool);
      const bannerMap = await storefront.loadBannerMap(pool);
      const siteName = settings.site_name || 'Galaxy Subz × Zayron';
      const logoFile = settings.logo_file || 'logo.png';
      const waNumber = settings.wa_number || process.env.WA_NUMBER || '';
      const shellJson = storefront.shellJson(cats, allProducts, settings, waNumber);
      res.render('category', {
        title: cat.name + ' · ' + siteName,
        siteName, logoFile, waNumber, cats, cat, products, bannerMap, settings, shellJson
      });
    } catch (e) { res.status(500).send('Category error: ' + e.message); }
  });

  return router;
};
GSZ_CATR_EOF

cat > "$APP/views/partials/store_top.ejs" <<'GSZ_TOP_EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title><%= typeof title!=='undefined' ? title : siteName %></title>
<link rel="icon" href="/static/img/<%= logoFile %>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,600;12..96,700;12..96,800&family=Hanken+Grotesk:wght@400;500;600;700&display=swap">
<link rel="stylesheet" href="/static/css/app.css?v=9">
</head>
<body>

<!-- OFFER BAR (always on, no close button) -->
<div class="offer">
  <div class="offer-in">
    <div class="marquee" aria-hidden="true"><ul id="marqueeList"></ul></div>
    <button class="code-chip" id="codeChip" title="Copy code">
      <svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2"/><rect x="9" y="3" width="6" height="4" rx="1"/></svg>
      SAVE 10% <b>GALAXY10</b></button>
  </div>
</div>

<!-- HEADER (universal) -->
<header class="hd" id="hd">
  <div class="wrap hd-in">
    <a href="/" class="brand" aria-label="<%= siteName %> — home">
      <img src="/static/img/<%= logoFile %>" alt="<%= siteName %>" onerror="this.style.display='none';this.nextElementSibling.style.display='inline-flex'">
      <span class="wordmark" style="display:none;align-items:center;gap:6px">Galaxy&nbsp;Subz <span class="grad-text">× Zayron</span></span>
    </a>
    <nav class="nav" aria-label="Primary">
      <% cats.slice(0,5).forEach(function(c){ %><a href="/category/<%= c.slug %>"><%= c.name %></a><% }); %>
      <a href="#" data-toast="Resellers page — coming soon.">Resellers</a>
    </nav>
    <div class="hd-search">
      <svg class="ic ic-sm si" viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
      <input id="searchInput" type="text" placeholder="Search Netflix, IPTV, VPN, Canva…" autocomplete="off" aria-label="Search products">
      <div class="sresults" id="searchRes"></div>
    </div>
    <div class="hd-sp"></div>
    <div class="hd-tools">
      <div class="pos-rel">
        <button class="region" id="regionBtn" aria-haspopup="true">
          <img class="flag" id="regionFlag" src="" alt=""><span id="regionLabel">PK · Rs</span>
          <svg class="ic ic-sm" viewBox="0 0 24 24" style="opacity:.5"><path d="m6 9 6 6 6-6"/></svg>
        </button>
        <div class="rmenu" id="regionMenu"></div>
      </div>
      <a class="btn btn-wa hd-wa" href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')) : '#' %>" target="_blank" rel="noopener">
        <svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg><span class="label">Order on WhatsApp</span></a>
      <button class="icon-btn burger" id="burger" aria-label="Menu"><svg class="ic" viewBox="0 0 24 24"><path d="M3 6h18M3 12h18M3 18h18"/></svg></button>
    </div>
  </div>
</header>
GSZ_TOP_EOF

cat > "$APP/views/partials/store_bottom.ejs" <<'GSZ_BOT_EOF'
<!-- BRAND FAMILY -->
<div class="house">
  <div class="wrap house-in">
    <span class="lbl"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/><path d="m9 12 2 2 4-4"/></svg>One trusted family of brands</span>
    <div class="brands">
      <a href="https://galaxytools.net" target="_blank" rel="noopener">galaxytools.net</a>
      <a href="https://galaxy-tools.com" target="_blank" rel="noopener">galaxy-tools.com</a>
      <a href="https://zayron.tv" target="_blank" rel="noopener">zayron.tv</a>
      <a href="https://zayron.pro" target="_blank" rel="noopener">zayron.pro</a>
    </div>
  </div>
</div>

<!-- FOOTER -->
<footer class="ft">
  <div class="wrap">
    <div class="ft-top">
      <div class="ft-brand">
        <img src="/static/img/<%= logoFile %>" alt="<%= siteName %>" onerror="this.style.display='none';this.nextElementSibling.style.display='inline-flex'">
        <span class="wordmark" style="display:none;align-items:center;gap:6px">Galaxy&nbsp;Subz <span class="grad-text">× Zayron</span></span>
        <p>Premium digital subscriptions and IPTV, delivered fast and backed by real support — one trusted home for streaming, tools, VPNs and players.</p>
        <div class="social">
          <a href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')) : '#' %>" target="_blank" rel="noopener" aria-label="WhatsApp"><svg class="ic" viewBox="0 0 24 24"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg></a>
          <a href="#" data-toast="Instagram link — set in admin." aria-label="Instagram"><svg class="ic" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none"/></svg></a>
          <a href="#" data-toast="Facebook link — set in admin." aria-label="Facebook"><svg class="ic" viewBox="0 0 24 24"><path d="M14 9h3V5h-3c-2.2 0-4 1.8-4 4v2H7v4h3v6h4v-6h3l1-4h-4V9c0-.6.4-1 1-1Z"/></svg></a>
          <a href="#" data-toast="Telegram link — set in admin." aria-label="Telegram"><svg class="ic" viewBox="0 0 24 24"><path d="m21 4-9 16-2.5-6.5L3 11l18-7Z"/><path d="M9.5 13.5 21 4"/></svg></a>
        </div>
      </div>
      <div class="ft-col"><h4>Shop</h4>
        <% cats.slice(0,6).forEach(function(c){ %><a href="/category/<%= c.slug %>"><%= c.name %></a><% }); %>
      </div>
      <div class="ft-col"><h4>Company</h4>
        <a href="#" data-toast="About — coming soon.">About us</a>
        <a href="#" data-toast="Resellers — coming soon.">Reseller panels</a>
        <a href="#" data-toast="Blog — coming soon.">Blog</a>
        <a href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')) : '#' %>" target="_blank" rel="noopener">Contact</a>
      </div>
      <div class="ft-col"><h4>Support</h4>
        <a href="#" data-toast="Order lookup — coming soon.">Track an order</a>
        <a href="#" data-toast="IPTV tools — coming soon.">Check line status</a>
        <a href="#" data-toast="Renewals — coming soon.">Renew IPTV</a>
        <a href="#" data-toast="FAQ — coming soon.">FAQ &amp; policies</a>
      </div>
    </div>
    <div class="ft-bottom">
      <span>© <%= new Date().getFullYear() %> <%= siteName %>. All rights reserved.</span>
      <div class="pays"><span class="pay">Pakistani banks</span><span class="pay">Binance</span><span class="pay">TapTap</span></div>
    </div>
  </div>
</footer>

<!-- MOBILE DRAWER -->
<div class="scrim-el" id="scrim"></div>
<aside class="drawer" id="drawer" aria-label="Menu">
  <div class="drawer-top">
    <img src="/static/img/<%= logoFile %>" alt="<%= siteName %>" onerror="this.style.display='none';this.nextElementSibling.style.display='inline-flex'">
    <span class="wordmark" style="display:none;align-items:center;gap:6px">Galaxy&nbsp;Subz <span class="grad-text">× Zayron</span></span>
    <button class="icon-btn" id="drawerX" aria-label="Close"><svg class="ic" viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12"/></svg></button>
  </div>
  <div class="drawer-cats" id="drawerCats"></div>
  <div class="drawer-foot">
    <div class="drawer-region" id="drawerRegion"></div>
    <a class="btn btn-wa" href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')) : '#' %>" target="_blank" rel="noopener"><svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>Order on WhatsApp</a>
  </div>
</aside>

<button class="toss" id="toss" style="display:none"></button>
<div class="toast" id="toast"></div>

<script>window.__DATA = <%- shellJson %>;</script>
<script src="/static/js/app.js?v=9" defer></script>
</body>
</html>
GSZ_BOT_EOF

cat > "$APP/views/home.ejs" <<'GSZ_HOME_EOF'
<%- include('partials/store_top') %>
<%
function esc(s){return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
var catBy={}; cats.forEach(function(c){catBy[c.slug]=c;});
function card(p){
  var cat=catBy[p.cat]||{};
  var img=p.image
    ? '<img class="pimg" loading="lazy" src="/static/img/'+esc(p.image)+'" alt="'+esc(p.name)+'">'
    : '<div class="pfallback" style="--g1:'+(cat.g1||'#2a6cff')+';--g2:'+(cat.g2||'#19c6ee')+'"><span>'+esc(p.name)+'</span></div>';
  var price = p.from>0
    ? '<div class="pfoot">'+(p.plans>1?'<span class="pfrom">Starts from</span>':'')+'<span class="pprice" data-pkr="'+p.from+'"></span></div>'
    : '<div class="pfoot"><span class="pfrom">Contact for price</span></div>';
  return '<a class="pcard" href="/product/'+esc(p.slug)+'">'+img+'<div class="pbody"><div class="pname">'+esc(p.name)+'</div><div class="pdesc">'+esc(p.descr)+'</div>'+price+'</div></a>';
}
function cardsFor(slug,n){return products.filter(function(p){return p.cat===slug;}).slice(0,n||4).map(card).join('');}
var trending = products.slice(0,8);
%>

<!-- HERO -->
<section class="hero">
  <% if (heroCats.length) { %>
  <div class="hero-stage" id="heroStage">
    <% heroCats.forEach(function(c,i){ var bm=bannerMap[c.slug]||{}; %>
      <div class="hslide<%= i===0?' on':'' %>" data-i="<%= i %>">
        <picture>
          <% if (bm.mobile) { %><source media="(max-width:720px)" srcset="/static/img/<%= bm.mobile %>"><% } %>
          <img src="/static/img/<%= bm.desktop || bm.mobile %>" alt="<%= c.name %>">
        </picture>
        <div class="veil"></div>
        <div class="cap">
          <h2><%= c.name %></h2>
          <p><%= c.tag || 'Premium subscriptions, delivered fast.' %></p>
          <a class="btn btn-primary btn-lg" href="/category/<%= c.slug %>">Shop <%= c.name %></a>
        </div>
      </div>
    <% }); %>
    <% if (heroCats.length>1) { %>
      <button class="hero-ar prev" id="heroPrev" aria-label="Previous"><svg class="ic" viewBox="0 0 24 24"><path d="m15 18-6-6 6-6"/></svg></button>
      <button class="hero-ar next" id="heroNext" aria-label="Next"><svg class="ic" viewBox="0 0 24 24"><path d="m9 6 6 6-6 6"/></svg></button>
      <div class="hero-dots" id="heroDots"></div>
    <% } %>
  </div>
  <% } else { %>
  <div class="hero-stage" style="display:grid;place-items:center;background:linear-gradient(120deg,#0b1030,#141a3a)">
    <div style="text-align:center;color:#fff;padding:40px">
      <h2 style="font-family:var(--display);font-weight:800;font-size:clamp(28px,5vw,52px);letter-spacing:-.02em;margin:0 0 12px">Premium subscriptions, delivered fast.</h2>
      <p style="color:#c7cdea;margin:0 0 22px">Upload your hero banners in Admin → Branding to feature them here.</p>
      <a class="btn btn-primary btn-lg" href="#cats">Browse the store</a>
    </div>
  </div>
  <% } %>
</section>

<!-- CREDIBILITY -->
<div class="stats"><div class="wrap"><div class="stats-in">
  <div class="stat"><b><span class="star">★</span> <%= settings.rating || '4.9' %></b><span class="lbl">Average customer rating</span></div>
  <div class="stat"><b class="tnum"><%= settings.delivered || '12,000+' %></b><span class="lbl">Orders delivered</span></div>
  <div class="stat"><b>Since <%= settings.since || '2021' %></b><span class="lbl">Trusted digital store</span></div>
</div></div></div>

<!-- CATEGORY GRID -->
<section class="section" id="cats">
  <div class="wrap">
    <div class="sec-head">
      <div><span class="eyebrow"><span class="dot"></span>Browse the store</span><h2>Shop by category</h2></div>
    </div>
    <div class="catgrid">
      <% cats.forEach(function(c){ %>
        <a class="cat-tile" href="/category/<%= c.slug %>" style="--g1:<%= c.g1 %>;--g2:<%= c.g2 %>">
          <span class="cg"><svg class="ic" viewBox="0 0 24 24"><%- c.icon %></svg></span>
          <span><b><%= c.name %></b><span class="n"><%= c.n %> product<%= c.n===1?'':'s' %></span></span>
        </a>
      <% }); %>
    </div>
  </div>
</section>

<!-- TRENDING -->
<% if (trending.length) { %>
<section class="section tint">
  <div class="wrap">
    <div class="sec-head">
      <div><span class="eyebrow"><span class="dot"></span>Most popular right now</span><h2>Trending products</h2></div>
    </div>
    <div class="pgrid"><%- trending.map(card).join('') %></div>
  </div>
</section>
<% } %>

<!-- PER-CATEGORY SECTIONS (varied rhythm) -->
<%
var usedShowcase=false; var tintToggle=false;
cats.forEach(function(c){
  var list=products.filter(function(p){return p.cat===c.slug;});
  if(!list.length) return;
  var bm=bannerMap[c.slug]||{};
  if(c.slug==='iptv'){ %>
    <section class="iptv-band">
      <% if (bm.desktop || bm.mobile) { %><img src="/static/img/<%= bm.desktop||bm.mobile %>" alt=""><% } %>
      <div class="wrap ib-in">
        <div class="ib-head">
          <span class="eyebrow"><span class="dot" style="background:var(--c)"></span>Live TV &amp; sports</span>
          <h2><%= c.name %></h2>
          <p>Thousands of channels and VOD in crisp quality — free trial, instant activation and renewals, on every device.</p>
        </div>
        <div class="pgrid g4"><%- cardsFor(c.slug,4) %></div>
        <div style="margin-top:22px"><a class="view-all" href="/category/<%= c.slug %>">View all <%= c.name %> →</a></div>
      </div>
    </section>
<%} else if(!usedShowcase && (bm.desktop||bm.mobile)){ usedShowcase=true; %>
    <section class="section">
      <div class="wrap">
        <div class="showcase">
          <a class="show-banner" href="/category/<%= c.slug %>">
            <img src="/static/img/<%= bm.desktop||bm.mobile %>" alt="<%= c.name %>">
            <div class="sb-cap"><h3><%= c.name %></h3><p><%= c.tag || 'Hand-picked premium picks.' %></p></div>
          </a>
          <div>
            <div class="sec-head"><div><span class="eyebrow"><span class="dot"></span>Featured</span><h2><%= c.name %></h2></div>
              <a class="view-all" href="/category/<%= c.slug %>">View all →</a></div>
            <div class="pgrid g4"><%- cardsFor(c.slug,4) %></div>
          </div>
        </div>
      </div>
    </section>
<%} else { tintToggle=!tintToggle; %>
    <section class="section<%= tintToggle?' tint':'' %>">
      <div class="wrap">
        <div class="sec-head">
          <div><span class="eyebrow"><span class="dot"></span><%= c.tag || 'Collection' %></span><h2><%= c.name %></h2></div>
          <a class="view-all" href="/category/<%= c.slug %>">View all <%= c.n %> →</a>
        </div>
        <div class="pgrid g4"><%- cardsFor(c.slug,4) %></div>
      </div>
    </section>
<% }
}); %>

<!-- REVIEWS -->
<section class="section tint">
  <div class="wrap">
    <div class="sec-head">
      <div><span class="eyebrow"><span class="dot"></span>What customers say</span><h2>Trusted by resellers &amp; viewers</h2></div>
    </div>
    <div class="rev-grid">
      <div class="tp-card">
        <div class="tp-score"><b><%= settings.rating || '4.9' %></b><span>/ 5</span></div>
        <div class="stars"><% for(var i=0;i<5;i++){ %><svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg><% } %></div>
        <div class="tp-sub">Based on <b class="tnum"><%= settings.reviews_count || '1,284' %></b> customer reviews</div>
        <div class="tp-logo"><svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg>Trustpilot</div>
      </div>
      <div class="rev-cards">
        <% reviews.forEach(function(r){ var initial=(r.author||'G').trim().charAt(0).toUpperCase(); %>
          <div class="rev">
            <div class="rs"><% for(var j=0;j<(r.stars||5);j++){ %><svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg><% } %></div>
            <p><%= r.body %></p>
            <div class="who"><span class="av"><%= initial %></span><div><b><%= r.author %></b><span><%= r.location || 'Verified buyer' %></span></div></div>
          </div>
        <% }); %>
      </div>
    </div>
  </div>
</section>

<%- include('partials/store_bottom') %>
GSZ_HOME_EOF

cat > "$APP/views/category.ejs" <<'GSZ_CATV_EOF'
<%- include('partials/store_top') %>
<%
function esc(s){return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
function card(p){
  var img=p.image
    ? '<img class="pimg" loading="lazy" src="/static/img/'+esc(p.image)+'" alt="'+esc(p.name)+'">'
    : '<div class="pfallback" style="--g1:'+(cat.g1||'#2a6cff')+';--g2:'+(cat.g2||'#19c6ee')+'"><span>'+esc(p.name)+'</span></div>';
  var price = p.from>0
    ? '<div class="pfoot">'+(p.plans>1?'<span class="pfrom">Starts from</span>':'')+'<span class="pprice" data-pkr="'+p.from+'"></span></div>'
    : '<div class="pfoot"><span class="pfrom">Contact for price</span></div>';
  return '<a class="pcard" href="/product/'+esc(p.slug)+'">'+img+'<div class="pbody"><div class="pname">'+esc(p.name)+'</div><div class="pdesc">'+esc(p.descr)+'</div>'+price+'</div></a>';
}
var bm = bannerMap[cat.slug] || {};
%>

<!-- CATEGORY HERO -->
<section class="hero">
  <% if (bm.desktop || bm.mobile) { %>
  <div class="hero-stage">
    <div class="hslide on">
      <picture>
        <% if (bm.mobile) { %><source media="(max-width:720px)" srcset="/static/img/<%= bm.mobile %>"><% } %>
        <img src="/static/img/<%= bm.desktop || bm.mobile %>" alt="<%= cat.name %>">
      </picture>
      <div class="veil"></div>
      <div class="cap"><h2><%= cat.name %></h2><p><%= cat.tag || 'Premium subscriptions, delivered fast.' %></p></div>
    </div>
  </div>
  <% } else { %>
  <div class="hero-stage" style="display:grid;place-items:center;background:linear-gradient(135deg,<%= cat.g1 %>,<%= cat.g2 %>)">
    <div style="text-align:center;color:#fff;padding:36px">
      <h2 style="font-family:var(--display);font-weight:800;font-size:clamp(28px,5vw,48px);letter-spacing:-.02em;margin:0"><%= cat.name %></h2>
      <p style="color:rgba(255,255,255,.85);margin:10px 0 0"><%= cat.tag || 'Premium subscriptions, delivered fast.' %></p>
    </div>
  </div>
  <% } %>
</section>

<!-- PRODUCTS -->
<section class="section">
  <div class="wrap">
    <div class="sec-head">
      <div>
        <span class="eyebrow"><a href="/" style="color:inherit">Home</a> &nbsp;/&nbsp; <%= cat.name %></span>
        <h2><%= cat.name %> <span style="color:var(--muted);font-weight:600;font-size:.6em">(<%= products.length %>)</span></h2>
      </div>
    </div>
    <% if (products.length) { %>
      <div class="pgrid"><%- products.map(card).join('') %></div>
    <% } else { %>
      <p style="color:var(--muted)">No products in this category yet. Please check back soon.</p>
    <% } %>
  </div>
</section>

<%- include('partials/store_bottom') %>
GSZ_CATV_EOF

cat > "$APP/public/css/app.css" <<'GSZ_CSS_EOF'
/* ============================================================
   GALAXY SUBZ × ZAYRON — storefront design system (v2)
   Light, neutral-led, restrained brand accents. One system.
   ============================================================ */
:root{
  --paper:#fbfbfd; --surface:#ffffff; --ink:#0e1430; --muted:#6b7391;
  --line:#eceef5; --line-2:#e3e6f1;
  --v:#7a2bff; --b:#2a6cff; --c:#19c6ee;
  --brand:linear-gradient(100deg,#7a2bff,#2a6cff 55%,#19c6ee);
  --ink-soft:#2a3152; --wash:#f4f6fb;
  --ok:#12b26a; --warn:#e8a33d;
  --display:'Bricolage Grotesque',system-ui,sans-serif;
  --body:'Hanken Grotesk',system-ui,'Segoe UI',sans-serif;
  --wrap:1200px; --gut:clamp(16px,4vw,40px);
  --r:16px; --r-sm:11px; --r-lg:22px;
  --shadow:0 1px 2px rgba(14,20,48,.04),0 14px 34px -22px rgba(14,20,48,.26);
  --shadow-lg:0 2px 6px rgba(14,20,48,.05),0 30px 60px -30px rgba(14,20,48,.34);
}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--paper);color:var(--ink);font-family:var(--body);
  font-size:16px;line-height:1.5;-webkit-font-smoothing:antialiased}
a{color:inherit;text-decoration:none}
img{max-width:100%;display:block}
ul{margin:0;padding:0;list-style:none}
button{font-family:inherit}
.wrap{max-width:var(--wrap);margin:0 auto;padding:0 var(--gut)}
.ic{width:22px;height:22px;stroke:currentColor;fill:none;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round}
.ic-sm{width:17px;height:17px}
.tnum{font-variant-numeric:tabular-nums}
.grad-text{background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent}

/* ---- buttons ---- */
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;
  font-weight:600;font-size:15px;border:0;border-radius:12px;padding:12px 20px;cursor:pointer;
  transition:transform .15s ease,box-shadow .15s ease,background .15s ease;white-space:nowrap}
.btn-primary{background:var(--brand);color:#fff;box-shadow:0 12px 26px -12px rgba(42,108,255,.85)}
.btn-primary:hover{transform:translateY(-1px);box-shadow:0 16px 30px -12px rgba(42,108,255,.95)}
.btn-dark{background:var(--ink);color:#fff}
.btn-dark:hover{transform:translateY(-1px)}
.btn-ghost{background:var(--surface);color:var(--ink);box-shadow:inset 0 0 0 1px var(--line-2)}
.btn-ghost:hover{box-shadow:inset 0 0 0 1.5px var(--b);color:var(--b)}
.btn-wa{background:#1fb457;color:#fff}
.btn-wa:hover{background:#19a04d;transform:translateY(-1px)}
.btn-lg{padding:15px 26px;font-size:16px;border-radius:14px}

/* ---- offer bar (no close button) ---- */
.offer{background:var(--ink);color:#fff;font-size:13.5px;overflow:hidden}
.offer-in{display:flex;align-items:center;gap:16px;height:40px;max-width:var(--wrap);margin:0 auto;padding:0 var(--gut)}
.marquee{flex:1;overflow:hidden;mask:linear-gradient(90deg,transparent,#000 6%,#000 94%,transparent)}
.marquee ul{display:flex;gap:40px;width:max-content;animation:marq 32s linear infinite}
.marquee li{display:flex;align-items:center;gap:8px;color:#cdd3ea;white-space:nowrap}
.marquee li svg{color:var(--c)}
@keyframes marq{to{transform:translateX(-50%)}}
.code-chip{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.1);color:#fff;
  border:0;border-radius:999px;padding:6px 13px;font-size:12.5px;font-weight:600;cursor:pointer;white-space:nowrap}
.code-chip b{letter-spacing:.04em}
.code-chip:hover{background:rgba(255,255,255,.18)}

/* ---- header ---- */
.hd{position:sticky;top:0;z-index:50;background:rgba(251,251,253,.86);backdrop-filter:blur(14px);
  border-bottom:1px solid transparent;transition:border-color .2s,box-shadow .2s}
.hd.scrolled{border-color:var(--line);box-shadow:0 10px 30px -24px rgba(14,20,48,.4)}
.hd-in{display:flex;align-items:center;gap:20px;height:76px}
.brand{display:flex;align-items:center;gap:9px;flex:none}
.brand img{height:40px;width:auto}
.wordmark{font-family:var(--display);font-weight:800;font-size:21px;letter-spacing:-.02em}
.nav{display:flex;align-items:center;gap:4px}
.nav a{padding:9px 13px;border-radius:9px;font-weight:600;font-size:15px;color:var(--ink-soft);transition:.15s}
.nav a:hover{background:var(--wash);color:var(--ink)}
.hd-search{flex:1;max-width:360px;position:relative}
.hd-search input{width:100%;height:44px;border:1px solid var(--line-2);border-radius:12px;background:var(--surface);
  padding:0 14px 0 42px;font-size:14.5px;font-family:inherit;color:var(--ink)}
.hd-search input:focus{outline:2px solid var(--b);outline-offset:1px;border-color:transparent}
.hd-search .si{position:absolute;left:13px;top:50%;transform:translateY(-50%);color:var(--muted)}
.hd-sp{flex:1}
.hd-tools{display:flex;align-items:center;gap:10px;flex:none}
.region{display:inline-flex;align-items:center;gap:7px;background:var(--surface);border:1px solid var(--line-2);
  border-radius:11px;padding:8px 11px;font-weight:600;font-size:13.5px;cursor:pointer;color:var(--ink)}
.region:hover{border-color:var(--b)}
.region .flag{width:18px;height:13px;border-radius:2px;object-fit:cover}
.pos-rel{position:relative}
.rmenu{position:absolute;right:0;top:calc(100% + 8px);background:var(--surface);border:1px solid var(--line);
  border-radius:12px;box-shadow:var(--shadow-lg);padding:6px;min-width:170px;display:none;z-index:60}
.rmenu.on{display:block}
.rmenu button{display:flex;align-items:center;gap:9px;width:100%;border:0;background:none;padding:9px 11px;
  border-radius:8px;font-weight:600;font-size:13.5px;cursor:pointer;color:var(--ink-soft)}
.rmenu button:hover{background:var(--wash)}
.rmenu button.on{color:var(--b)}
.rmenu .flag{width:18px;height:13px;border-radius:2px}
.icon-btn{display:inline-grid;place-items:center;width:44px;height:44px;border-radius:11px;background:var(--surface);
  border:1px solid var(--line-2);color:var(--ink);cursor:pointer;position:relative}
.icon-btn:hover{border-color:var(--b);color:var(--b)}
.burger{display:none}
.hd-wa .label{display:inline}

/* search dropdown (inline, no popup) */
.sresults{position:absolute;left:0;right:0;top:calc(100% + 8px);background:var(--surface);border:1px solid var(--line);
  border-radius:14px;box-shadow:var(--shadow-lg);padding:6px;max-height:min(70vh,440px);overflow:auto;display:none;z-index:70}
.sresults.on{display:block}
.sresult{display:flex;align-items:center;gap:12px;padding:9px 11px;border-radius:10px}
.sresult:hover{background:var(--wash)}
.sresult .th{width:40px;height:40px;border-radius:9px;object-fit:cover;flex:none;background:var(--wash)}
.sresult .nm{font-weight:600;font-size:14px}
.sresult .mt{font-size:12.5px;color:var(--muted)}
.sresult .pr{margin-left:auto;font-weight:700;font-size:13.5px}
.sempty{padding:18px 12px;color:var(--muted);font-size:14px;text-align:center}

/* ---- hero (full-bleed, no borders) ---- */
.hero{position:relative;width:100%}
.hero-stage{position:relative;width:100%;aspect-ratio:1942/809;overflow:hidden;background:var(--wash)}
.hslide{position:absolute;inset:0;opacity:0;transition:opacity .7s ease;pointer-events:none}
.hslide.on{opacity:1;pointer-events:auto}
.hslide img{width:100%;height:100%;object-fit:cover;display:block}
.hslide .veil{position:absolute;inset:0;background:linear-gradient(90deg,rgba(6,10,28,.72),rgba(6,10,28,.18) 52%,transparent)}
.hslide .cap{position:absolute;left:0;bottom:0;padding:clamp(20px,5vw,56px) var(--gut);max-width:720px;color:#fff}
.hslide .cap h2{font-family:var(--display);font-weight:800;letter-spacing:-.025em;line-height:1.02;
  font-size:clamp(28px,5vw,56px);margin:0 0 14px;text-shadow:0 2px 30px rgba(0,0,0,.3)}
.hslide .cap p{font-size:clamp(14px,1.6vw,18px);color:#e7ebfb;margin:0 0 20px;max-width:46ch}
.hero-dots{position:absolute;right:var(--gut);bottom:18px;display:flex;gap:7px;z-index:3}
.hero-dots button{width:9px;height:9px;border-radius:999px;border:0;background:rgba(255,255,255,.45);cursor:pointer;padding:0}
.hero-dots button.on{background:#fff;width:24px}
.hero-ar{position:absolute;top:50%;transform:translateY(-50%);width:44px;height:44px;border-radius:999px;
  border:0;background:rgba(10,14,34,.42);color:#fff;display:grid;place-items:center;cursor:pointer;z-index:3}
.hero-ar:hover{background:rgba(10,14,34,.7)}
.hero-ar.prev{left:14px}.hero-ar.next{right:14px}
@media(max-width:720px){.hero-stage{aspect-ratio:1536/1024;max-height:78vh}.hero-ar{display:none}}

/* ---- credibility stats ---- */
.stats{border-bottom:1px solid var(--line)}
.stats-in{display:grid;grid-template-columns:repeat(3,1fr);gap:0;padding:26px 0}
.stat{text-align:center;padding:4px 16px;position:relative}
.stat+.stat{border-left:1px solid var(--line)}
.stat b{display:block;font-family:var(--display);font-weight:800;font-size:clamp(26px,3.4vw,38px);letter-spacing:-.02em;line-height:1}
.stat .lbl{display:block;margin-top:7px;color:var(--muted);font-size:13.5px;font-weight:500}
.stat .star{color:#f5b301}
@media(max-width:560px){.stats-in{padding:18px 0}.stat{padding:4px 8px}.stat .lbl{font-size:12px}}

/* ---- section rhythm ---- */
.section{padding:clamp(44px,6vw,78px) 0}
.section.tint{background:var(--wash)}
.sec-head{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;margin-bottom:30px}
.sec-head .eyebrow{display:inline-flex;align-items:center;gap:8px;font-weight:600;font-size:13.5px;color:var(--muted)}
.sec-head .eyebrow .dot{width:8px;height:8px;border-radius:999px;background:var(--brand)}
.sec-head h2{font-family:var(--display);font-weight:800;font-size:clamp(24px,3vw,34px);letter-spacing:-.02em;margin:6px 0 0;line-height:1.05}
.view-all{display:inline-flex;align-items:center;gap:6px;font-weight:600;font-size:14.5px;color:var(--b);flex:none}
.view-all:hover{text-decoration:underline}

/* ---- category grid ---- */
.catgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:14px}
.cat-tile{display:flex;align-items:center;gap:14px;background:var(--surface);border:1px solid var(--line);
  border-radius:var(--r);padding:16px;transition:transform .15s,box-shadow .15s,border-color .15s}
.cat-tile:hover{transform:translateY(-2px);box-shadow:var(--shadow);border-color:transparent}
.cat-tile .cg{width:46px;height:46px;border-radius:13px;display:grid;place-items:center;flex:none;color:#fff;
  background:linear-gradient(135deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.cat-tile .cg svg{stroke:#fff}
.cat-tile b{font-family:var(--display);font-weight:700;font-size:16px;letter-spacing:-.01em;display:block}
.cat-tile .n{color:var(--muted);font-size:13px}

/* ---- product grid + cards ---- */
.pgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:18px}
.pgrid.g4{grid-template-columns:repeat(4,1fr)}
@media(max-width:900px){.pgrid.g4{grid-template-columns:repeat(2,1fr)}}
@media(max-width:520px){.pgrid,.pgrid.g4{grid-template-columns:repeat(2,1fr);gap:12px}}
.pcard{display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--line);
  border-radius:var(--r);overflow:hidden;transition:transform .16s,box-shadow .16s,border-color .16s}
.pcard:hover{transform:translateY(-3px);box-shadow:var(--shadow-lg);border-color:transparent}
.pcard .pimg{aspect-ratio:1/1;width:100%;object-fit:cover;background:var(--wash)}
.pcard .pfallback{aspect-ratio:1/1;width:100%;display:grid;place-items:center;position:relative;overflow:hidden;
  background:linear-gradient(145deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.pcard .pfallback span{font-family:var(--display);font-weight:800;color:#fff;font-size:30px;letter-spacing:-.02em;
  opacity:.95;text-align:center;padding:0 14px;line-height:1.05}
.pcard .pbody{padding:14px 15px 16px;display:flex;flex-direction:column;gap:4px;flex:1}
.pcard .pname{font-family:var(--display);font-weight:700;font-size:16px;letter-spacing:-.01em;line-height:1.2}
.pcard .pdesc{color:var(--muted);font-size:13.5px;line-height:1.45;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.pcard .pfoot{margin-top:auto;padding-top:12px;display:flex;align-items:baseline;gap:6px}
.pcard .pfrom{color:var(--muted);font-size:12px;font-weight:500}
.pcard .pprice{font-family:var(--display);font-weight:800;font-size:17px;letter-spacing:-.01em}

/* ---- editorial showcase (banner-led category) ---- */
.showcase{display:grid;grid-template-columns:minmax(0,1fr);gap:22px}
.show-banner{position:relative;border-radius:var(--r-lg);overflow:hidden;aspect-ratio:1942/809;background:var(--wash)}
.show-banner img{width:100%;height:100%;object-fit:cover}
.show-banner .sb-cap{position:absolute;inset:0;display:flex;flex-direction:column;justify-content:flex-end;
  padding:clamp(18px,3vw,34px);background:linear-gradient(0deg,rgba(6,10,28,.78),transparent 70%);color:#fff}
.show-banner .sb-cap h3{font-family:var(--display);font-weight:800;font-size:clamp(20px,2.6vw,30px);letter-spacing:-.02em;margin:0 0 6px}
.show-banner .sb-cap p{margin:0;color:#dfe4f6;font-size:14.5px;max-width:48ch}

/* ---- IPTV immersive band ---- */
.iptv-band{position:relative;overflow:hidden;background:#070b1d;color:#fff}
.iptv-band>img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;opacity:.26}
.iptv-band .ib-in{position:relative;padding:clamp(44px,6vw,76px) 0}
.iptv-band .ib-head{max-width:620px;margin-bottom:28px}
.iptv-band .ib-head .eyebrow{color:var(--c)}
.iptv-band .ib-head h2{font-family:var(--display);font-weight:800;font-size:clamp(26px,3.4vw,40px);letter-spacing:-.025em;margin:8px 0 12px;line-height:1.03}
.iptv-band .ib-head p{color:#c7cdea;font-size:16px;max-width:52ch;margin:0}
.iptv-band .pcard{background:rgba(255,255,255,.05);border-color:rgba(255,255,255,.1)}
.iptv-band .pcard .pname{color:#fff}
.iptv-band .pcard .pdesc{color:#aab2d6}
.iptv-band .pcard .pprice{color:#fff}
.iptv-band .view-all{color:var(--c)}

/* ---- reviews ---- */
.rev-grid{display:grid;grid-template-columns:300px 1fr;gap:24px}
@media(max-width:820px){.rev-grid{grid-template-columns:1fr}}
.tp-card{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:26px;align-self:start}
.tp-score{display:flex;align-items:baseline;gap:6px}
.tp-score b{font-family:var(--display);font-weight:800;font-size:46px;letter-spacing:-.02em;line-height:1}
.tp-score span{color:var(--muted);font-weight:600}
.stars{display:flex;gap:3px;margin:12px 0 10px;color:#f5b301}
.stars svg{width:20px;height:20px;fill:currentColor;stroke:none}
.tp-sub{color:var(--muted);font-size:13.5px}
.tp-logo{display:flex;align-items:center;gap:7px;margin-top:16px;font-weight:700;font-size:15px}
.tp-logo svg{width:20px;height:20px;fill:#12b26a;stroke:none}
.rev-cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:16px}
.rev{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:18px}
.rev .rs{display:flex;gap:2px;color:#f5b301;margin-bottom:9px}
.rev .rs svg{width:15px;height:15px;fill:currentColor;stroke:none}
.rev p{margin:0 0 14px;font-size:14.5px;line-height:1.5;color:var(--ink-soft)}
.rev .who{display:flex;align-items:center;gap:10px}
.rev .av{width:34px;height:34px;border-radius:999px;display:grid;place-items:center;color:#fff;font-weight:700;font-size:13px;background:var(--brand)}
.rev .who b{font-size:13.5px;display:block}
.rev .who span{font-size:12px;color:var(--muted)}

/* ---- brand family ---- */
.house{border-top:1px solid var(--line);border-bottom:1px solid var(--line);background:var(--surface)}
.house-in{display:flex;align-items:center;gap:22px;flex-wrap:wrap;padding:22px 0}
.house .lbl{display:inline-flex;align-items:center;gap:8px;color:var(--muted);font-size:13.5px;font-weight:600}
.house .lbl svg{color:var(--ok)}
.brands{display:flex;gap:10px;flex-wrap:wrap}
.brands a{font-family:var(--display);font-weight:700;font-size:15px;color:var(--ink-soft);
  padding:7px 14px;border-radius:999px;background:var(--wash)}
.brands a:hover{color:var(--b)}

/* ---- footer ---- */
.ft{background:var(--ink);color:#c7cdea;padding:56px 0 30px}
.ft-top{display:grid;grid-template-columns:1.6fr 1fr 1fr 1fr;gap:34px}
@media(max-width:820px){.ft-top{grid-template-columns:1fr 1fr}}
@media(max-width:520px){.ft-top{grid-template-columns:1fr}}
.ft-brand img{height:38px;margin-bottom:12px}
.ft-brand .wordmark{color:#fff}
.ft-brand p{font-size:14px;line-height:1.55;max-width:38ch;margin:10px 0 16px}
.social{display:flex;gap:10px}
.social a{width:38px;height:38px;border-radius:10px;display:grid;place-items:center;background:rgba(255,255,255,.07);color:#fff}
.social a:hover{background:var(--brand)}
.ft-col h4{color:#fff;font-family:var(--display);font-size:14px;font-weight:700;margin:0 0 14px;letter-spacing:.01em}
.ft-col a{display:block;font-size:14px;padding:5px 0;color:#aab2d6}
.ft-col a:hover{color:#fff}
.ft-bottom{display:flex;align-items:center;justify-content:space-between;gap:14px;flex-wrap:wrap;
  margin-top:36px;padding-top:22px;border-top:1px solid rgba(255,255,255,.1);font-size:13px}
.pays{display:flex;gap:8px;flex-wrap:wrap}
.pay{background:rgba(255,255,255,.07);border-radius:7px;padding:5px 11px;font-size:12.5px;font-weight:600;color:#cdd3ea}

/* ---- drawer (mobile) ---- */
.scrim-el{position:fixed;inset:0;background:rgba(10,14,34,.5);opacity:0;pointer-events:none;transition:.25s;z-index:80}
.scrim-el.on{opacity:1;pointer-events:auto}
.drawer{position:fixed;top:0;right:0;bottom:0;width:min(86vw,340px);background:var(--surface);z-index:90;
  transform:translateX(100%);transition:transform .28s ease;display:flex;flex-direction:column;padding:18px}
.drawer.on{transform:none}
.drawer-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:12px}
.drawer-top img{height:34px}
.drawer-cats{display:flex;flex-direction:column;gap:4px;margin:8px 0}
.dcat{display:flex;align-items:center;gap:12px;border:0;background:none;padding:11px 10px;border-radius:11px;cursor:pointer;text-align:left;color:var(--ink)}
.dcat:hover{background:var(--wash)}
.dcat .cg{width:38px;height:38px;border-radius:10px;display:grid;place-items:center;color:#fff;flex:none;
  background:linear-gradient(135deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.dcat b{font-weight:700;font-size:14.5px}
.dcat .n{font-size:12px;color:var(--muted)}
.drawer-foot{margin-top:auto;padding-top:14px;border-top:1px solid var(--line);display:flex;flex-direction:column;gap:12px}
.drawer-region{display:flex;gap:8px}
.drawer-region button{flex:1;border:1px solid var(--line-2);background:var(--surface);border-radius:9px;padding:9px;font-weight:600;cursor:pointer;color:var(--ink-soft)}
.drawer-region button.on{border-color:var(--b);color:var(--b)}

/* ---- toss (social proof popup) ---- */
.toss{position:fixed;left:18px;bottom:18px;z-index:70;display:flex;align-items:center;gap:12px;
  background:var(--surface);border:1px solid var(--line);border-radius:14px;box-shadow:var(--shadow-lg);
  padding:11px 14px;max-width:320px;cursor:pointer;transform:translateY(140%);transition:transform .4s cubic-bezier(.2,.7,.3,1);text-align:left}
.toss.on{transform:none}
.toss .tt{width:40px;height:40px;border-radius:10px;display:grid;place-items:center;color:#fff;flex:none;background:var(--brand)}
.toss .tb b{font-size:13.5px;display:block}
.toss .tb span{font-size:12px;color:var(--muted)}
.toss .tx{position:absolute;top:-8px;right:-8px;width:22px;height:22px;border-radius:999px;background:var(--ink);
  color:#fff;border:0;display:grid;place-items:center;cursor:pointer;font-size:12px}

/* ---- toast ---- */
.toast{position:fixed;left:50%;bottom:26px;transform:translateX(-50%) translateY(140%);z-index:95;
  background:var(--ink);color:#fff;border-radius:12px;padding:12px 18px;font-size:14px;font-weight:500;
  box-shadow:var(--shadow-lg);transition:transform .3s;max-width:90vw}
.toast.on{transform:translateX(-50%)}

/* ---- responsive header ---- */
@media(max-width:1040px){
  .nav{display:none}
  .hd-search{max-width:none}
}
@media(max-width:760px){
  .hd-in{height:64px;gap:12px}
  .hd-search{display:none}
  .hd-wa .label{display:none}
  .hd-wa{padding:0;width:44px;height:44px;border-radius:11px}
  .burger{display:inline-grid}
  .region{display:none}
}
@media(prefers-reduced-motion:reduce){
  *{animation-duration:.001ms !important;transition-duration:.001ms !important}
  .marquee ul{animation:none}
}
GSZ_CSS_EOF

cat > "$APP/public/js/app.js" <<'GSZ_JS_EOF'
/* ===== Galaxy Subz × Zayron — storefront (v2) =====
   Server renders the markup; this handles interaction only:
   region prices, live search, hero carousel, drawer, marquee, toss. */
(function(){
'use strict';
var D = (window.__DATA)||{cats:[],products:[],settings:{},wa:''};
var CATS = D.cats||[], PRODUCTS = D.products||[];
var reduce = matchMedia('(prefers-reduced-motion:reduce)').matches;
var $ = function(s,r){return (r||document).querySelector(s);};
var $$ = function(s,r){return Array.prototype.slice.call((r||document).querySelectorAll(s));};

/* ---------- region + prices ---------- */
var REGIONS=[
  {code:'PK',cur:'Rs',rate:1,label:'PK · Rs',cc:'pk'},
  {code:'US',cur:'$',rate:0.0036,label:'US · $',cc:'us'},
  {code:'GB',cur:'£',rate:0.0028,label:'UK · £',cc:'gb'},
  {code:'AE',cur:'AED',rate:0.013,label:'AE · AED',cc:'ae'}
];
var REGION=REGIONS[0];
try{var sv=localStorage.getItem('gsz_region');if(sv){var f=REGIONS.filter(function(r){return r.code===sv;})[0];if(f)REGION=f;}}catch(e){}
function flag(cc){return 'https://flagcdn.com/24x18/'+cc+'.png';}
function money(pkr){pkr=Number(pkr)||0;var v=pkr*REGION.rate;
  if(REGION.cur==='Rs')return 'Rs '+Math.round(pkr).toLocaleString('en-US');
  return REGION.cur+' '+(v<10?v.toFixed(2):Math.round(v).toLocaleString('en-US'));}
function paintPrices(root){$$('[data-pkr]',root).forEach(function(el){el.textContent=money(el.dataset.pkr);});}
function setRegion(code){
  var f=REGIONS.filter(function(r){return r.code===code;})[0]; if(!f)return;
  REGION=f;
  var lab=$('#regionLabel'); if(lab)lab.textContent=f.label;
  var fl=$('#regionFlag'); if(fl)fl.src=flag(f.cc);
  paintPrices();
  $$('#regionMenu button').forEach(function(b){b.classList.toggle('on',b.dataset.region===code);});
  $$('#drawerRegion button').forEach(function(b){b.classList.toggle('on',b.dataset.region===code);});
  try{localStorage.setItem('gsz_region',code);}catch(e){}
}
function buildRegionMenu(){
  var m=$('#regionMenu'); if(m)m.innerHTML=REGIONS.map(function(r){
    return '<button data-region="'+r.code+'" class="'+(r.code===REGION.code?'on':'')+'"><img class="flag" src="'+flag(r.cc)+'" alt="">'+r.label+'</button>';}).join('');
  var dr=$('#drawerRegion'); if(dr)dr.innerHTML=REGIONS.map(function(r){
    return '<button data-region="'+r.code+'" class="'+(r.code===REGION.code?'on':'')+'">'+r.cur+'</button>';}).join('');
}

/* ---------- marquee ---------- */
function buildMarquee(){
  var el=$('#marqueeList'); if(!el)return;
  var items=['Instant automated delivery','Pay in PKR, USD or crypto','Verified before we deliver','Real WhatsApp support','Free IPTV trial available'];
  var shield='<svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/></svg>';
  var row=items.map(function(t){return '<li>'+shield+t+'</li>';}).join('');
  el.innerHTML=row+row;
}

/* ---------- drawer ---------- */
function buildDrawerCats(){
  var el=$('#drawerCats'); if(!el)return;
  el.innerHTML=CATS.map(function(c){
    return '<a class="dcat" href="/category/'+c.slug+'" style="--g1:'+(c.g1||'#2a6cff')+';--g2:'+(c.g2||'#19c6ee')+'">'+
      '<span class="cg"><svg class="ic" viewBox="0 0 24 24">'+(c.icon||'')+'</svg></span>'+
      '<span><b>'+c.name+'</b><span class="n">'+c.n+' product'+(c.n===1?'':'s')+'</span></span></a>';}).join('');
}
function openDrawer(){$('#drawer').classList.add('on');$('#scrim').classList.add('on');}
function closeDrawer(){$('#drawer').classList.remove('on');$('#scrim').classList.remove('on');}

/* ---------- live search (inline, no popup) ---------- */
function searchThumb(p){
  if(p.image)return '<img class="th" src="/static/img/'+p.image+'" alt="">';
  return '<span class="th" style="display:grid;place-items:center;color:#fff;font-weight:700;background:linear-gradient(135deg,#2a6cff,#19c6ee)">'+(p.name||'?').charAt(0).toUpperCase()+'</span>';
}
function runSearch(q){
  var box=$('#searchRes'); if(!box)return;
  q=(q||'').trim().toLowerCase();
  if(!q){box.classList.remove('on');box.innerHTML='';return;}
  var hits=PRODUCTS.filter(function(p){return (p.name||'').toLowerCase().indexOf(q)>-1 || (p.cat||'').toLowerCase().indexOf(q)>-1;}).slice(0,8);
  if(!hits.length){box.innerHTML='<div class="sempty">No products match “'+q.replace(/</g,'')+'”.</div>';box.classList.add('on');return;}
  box.innerHTML=hits.map(function(p){
    return '<a class="sresult" href="/product/'+p.slug+'">'+searchThumb(p)+
      '<span><span class="nm">'+p.name+'</span><span class="mt">'+(p.catName||p.cat||'')+'</span></span>'+
      (p.from>0?'<span class="pr">'+money(p.from)+'</span>':'')+'</a>';}).join('');
  box.classList.add('on');
}

/* ---------- hero carousel (opacity only, no zoom) ---------- */
function initHero(){
  var stage=$('#heroStage'); if(!stage)return;
  var slides=$$('.hslide',stage); if(slides.length<2){return;}
  var dots=$('#heroDots'), cur=0, timer;
  if(dots)dots.innerHTML=slides.map(function(_,i){return '<button data-i="'+i+'" class="'+(i===0?'on':'')+'" aria-label="Slide '+(i+1)+'"></button>';}).join('');
  function go(i){cur=(i+slides.length)%slides.length;
    slides.forEach(function(s,k){s.classList.toggle('on',k===cur);});
    if(dots)$$('button',dots).forEach(function(b,k){b.classList.toggle('on',k===cur);});}
  function start(){if(reduce)return;clearInterval(timer);timer=setInterval(function(){go(cur+1);},6500);}
  var pv=$('#heroPrev'),nx=$('#heroNext');
  if(pv)pv.onclick=function(){go(cur-1);start();};
  if(nx)nx.onclick=function(){go(cur+1);start();};
  if(dots)dots.addEventListener('click',function(e){var b=e.target.closest('button');if(b){go(+b.dataset.i);start();}});
  stage.addEventListener('mouseenter',function(){clearInterval(timer);});
  stage.addEventListener('mouseleave',start);
  start();
}

/* ---------- toss (social proof) — slow, minutes apart ---------- */
var tossT;
function showToss(){
  var el=$('#toss'); if(!el||!PRODUCTS.length)return;
  var cities=['Karachi','Lahore','Islamabad','Dubai','London','Rawalpindi','Faisalabad','Manchester','Toronto','Riyadh'];
  var p=PRODUCTS[Math.floor(Math.random()*PRODUCTS.length)];
  var city=cities[Math.floor(Math.random()*cities.length)];
  var mins=2+Math.floor(Math.random()*28);
  el.innerHTML='<span class="tt"><svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M20 6 9 17l-5-5"/></svg></span>'+
    '<span class="tb"><b>'+p.name+'</b><span>Someone in '+city+' ordered · '+mins+' min ago</span></span>'+
    '<button class="tx" aria-label="Dismiss">✕</button>';
  el.href='/product/'+p.slug; el.style.display='flex';
  requestAnimationFrame(function(){el.classList.add('on');});
  clearTimeout(tossT); tossT=setTimeout(function(){el.classList.remove('on');},6500);
}
function startToss(){
  if(reduce)return;
  setTimeout(function loop(){showToss();setTimeout(loop,180000+Math.random()*180000);},45000);
}

/* ---------- toast ---------- */
var toastT;
function toast(m){var t=$('#toast');if(!t)return;t.textContent=m;t.classList.add('on');clearTimeout(toastT);toastT=setTimeout(function(){t.classList.remove('on');},2600);}

/* ---------- wire ---------- */
function wire(){
  buildRegionMenu(); buildMarquee(); buildDrawerCats();
  setRegion(REGION.code); paintPrices();
  initHero(); startToss();

  var rb=$('#regionBtn'); if(rb)rb.onclick=function(e){e.stopPropagation();$('#regionMenu').classList.toggle('on');};
  document.addEventListener('click',function(e){
    if(!e.target.closest('.pos-rel')){var m=$('#regionMenu');if(m)m.classList.remove('on');}
    var rbtn=e.target.closest('[data-region]'); if(rbtn){setRegion(rbtn.dataset.region);var m2=$('#regionMenu');if(m2)m2.classList.remove('on');}
    var sc=e.target.closest('[data-scroll]'); if(sc){e.preventDefault();var t=document.getElementById(sc.dataset.scroll);if(t)window.scrollTo({top:t.getBoundingClientRect().top+scrollY-90,behavior:'smooth'});}
    var tt=e.target.closest('[data-toast]'); if(tt){e.preventDefault();toast(tt.dataset.toast);}
    if(!e.target.closest('.hd-search')){var sr=$('#searchRes');if(sr)sr.classList.remove('on');}
  });

  var si=$('#searchInput');
  if(si){si.addEventListener('input',function(){runSearch(si.value);});
    si.addEventListener('focus',function(){if(si.value)runSearch(si.value);});}

  var bg=$('#burger'); if(bg)bg.onclick=openDrawer;
  var dx=$('#drawerX'); if(dx)dx.onclick=closeDrawer;
  var sc=$('#scrim'); if(sc)sc.onclick=closeDrawer;

  var cc=$('#codeChip'); if(cc)cc.onclick=function(){try{navigator.clipboard.writeText('GALAXY10');toast('Code GALAXY10 copied');}catch(e){toast('Code: GALAXY10');}};

  var toss=$('#toss'); if(toss)toss.addEventListener('click',function(e){if(e.target.closest('.tx')){e.preventDefault();toss.classList.remove('on');}});

  var hd=$('#hd'); addEventListener('scroll',function(){hd.classList.toggle('scrolled',scrollY>8);},{passive:true});
  addEventListener('keydown',function(e){if(e.key==='Escape'){closeDrawer();var sr=$('#searchRes');if(sr)sr.classList.remove('on');var rm=$('#regionMenu');if(rm)rm.classList.remove('on');}});
}
if(document.readyState!=='loading')wire(); else document.addEventListener('DOMContentLoaded',wire);
})();
GSZ_JS_EOF

cat > "$APP/server.js" <<'GSZ_SRV_EOF'
require('dotenv').config();
const path = require('path');
const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const session = require('express-session');
const { Pool } = require('pg');
const storefront = require('./lib/storefront');

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

app.get('/health', async (req, res) => {
  try {
    const c = await pool.query('SELECT count(*)::int AS n FROM categories');
    const p = await pool.query('SELECT count(*)::int AS n FROM products');
    const b = await pool.query('SELECT count(*)::int AS n FROM banners');
    res.json({ ok: true, categories: c.rows[0].n, products: p.rows[0].n, banners: b.rows[0].n });
  } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
});

// ---- admin + catalog + orders + product-image (all under /admin) ----
const adminRouter = require('./routes/admin')(pool);
app.use('/admin', adminRouter);
const adminCatalogRouter = require('./routes/adminCatalog')(pool);
app.use('/admin', adminCatalogRouter);
const adminOrdersRouter = require('./routes/adminOrders')(pool);
app.use('/admin', adminOrdersRouter);
const adminProductImageRouter = require('./routes/adminProductImage')(pool);
app.use('/admin', adminProductImageRouter);

// ---- public ----
const productsRouter = require('./routes/products')(pool);
app.use('/product', productsRouter);
const categoryRouter = require('./routes/category')(pool);
app.use('/category', categoryRouter);
const checkoutRouter = require('./routes/checkout')(pool);
app.use('/', checkoutRouter);

// ---- homepage ----
async function homeData() {
  const cats = await storefront.loadCats(pool);
  const products = await storefront.loadProducts(pool);
  const settings = await storefront.loadSettings(pool);
  const bannerMap = await storefront.loadBannerMap(pool);
  const reviews = (await pool.query(
    'SELECT author, location, stars, body FROM reviews WHERE approved ORDER BY id DESC LIMIT 6')).rows;
  const siteName = settings.site_name || 'Galaxy Subz × Zayron';
  const logoFile = settings.logo_file || 'logo.png';
  const waNumber = settings.wa_number || process.env.WA_NUMBER || '';
  const heroCats = cats.filter(c => bannerMap[c.slug] && (bannerMap[c.slug].desktop || bannerMap[c.slug].mobile));
  const shellJson = storefront.shellJson(cats, products, settings, waNumber);
  return { title: siteName, siteName, logoFile, waNumber, cats, products, bannerMap, reviews, settings, heroCats, shellJson };
}

app.get('/', async (req, res) => {
  try { const d = await homeData(); res.render('home', d); }
  catch (e) { res.status(500).send('Home render error: ' + e.message); }
});

const PORT = process.env.PORT || 3600;
app.listen(PORT, '0.0.0.0', () => console.log('[gsz] listening on ' + PORT));
GSZ_SRV_EOF

echo "[ok] all files written"

# ---------- validate ----------
node --check "$APP/server.js"           || { restore; exit 1; }
node --check "$APP/lib/storefront.js"   || { restore; exit 1; }
node --check "$APP/routes/category.js"  || { restore; exit 1; }
node --check "$APP/public/js/app.js"    || { restore; exit 1; }
echo "[ok] all JS parses clean"

pm2 restart gsz --update-env >/dev/null
sleep 2

SLUG=$(PSQL -tAc "SELECT slug FROM products ORDER BY sort,id LIMIT 1" | tr -d '[:space:]')
CSLUG=$(PSQL -tAc "SELECT slug FROM categories WHERE active ORDER BY sort,id LIMIT 1" | tr -d '[:space:]')
HOME=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
CAT=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/category/$CSLUG")
PP=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/product/$SLUG")
HEALTH=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health")

OKALL=1
echo "$HOME" | grep -q "Shop by category"     || { echo "FAIL: homepage did not render new design"; OKALL=0; }
echo "$HOME" | grep -q "pcard"                || { echo "FAIL: product cards missing on homepage"; OKALL=0; }
echo "$HOME" | grep -q "searchInput"          || { echo "FAIL: header search missing"; OKALL=0; }
[ "$CAT" = "200" ]                            || { echo "FAIL: category page (HTTP $CAT)"; OKALL=0; }
[ "$PP" = "200" ]                             || { echo "FAIL: product page broke (HTTP $PP)"; OKALL=0; }
[ "$HEALTH" = "200" ]                         || { echo "FAIL: health (HTTP $HEALTH)"; OKALL=0; }

if [ "$OKALL" != "1" ]; then
  echo "CHECK FAILED — rolling back Step 9"; restore; pm2 logs gsz --lines 30 --nostream || true; exit 1
fi

echo "============================================================"
echo " STEP 9 COMPLETE — storefront redesign is live"
echo "   home:      http://143.198.209.68:$PORT/"
echo "   category:  http://143.198.209.68:$PORT/category/$CSLUG"
echo "   Universal header + live search, full-bleed hero, image-led"
echo "   cards (Starts from), curated sections, category pages."
echo "   Upload product images (Admin → Products) to replace the"
echo "   gradient fallbacks on cards."
echo "============================================================"
