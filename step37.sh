#!/usr/bin/env bash
# ============================================================
#  STEP 37: home tidy — stats band separated from hero, Shop-by-Category
#  centered, category product-counts removed. Scoped styles (no !important).
#  Auto-rollback.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -f "$APP/views/home.ejs" ] || { echo "ABORT: home.ejs not found"; exit 1; }
cd "$APP"
set -a; . "$APP/.env"; set +a
TS=$(date +%s); BK="$APP/.bak-step37-$TS"; mkdir -p "$BK"
cp views/home.ejs "$BK/home.ejs"
restore(){ echo "!! ROLLBACK"; cp "$BK/home.ejs" views/home.ejs 2>/dev/null||true; pm2 restart gsz >/dev/null 2>&1||true; }
trap 'restore' ERR
echo "== Step 37 (home: stats band + centered categories + no counts) =="

cat > views/home.ejs <<'EOF_HOME'
<%- include('partials/store_top') %>
<style>
  /* stats band — lifted off the hero into its own section */
  #statsBand{margin:0;padding:24px 0;background:linear-gradient(180deg,rgba(255,255,255,.05),rgba(255,255,255,0));
    border-top:1px solid rgba(255,255,255,.08);border-bottom:1px solid rgba(255,255,255,.08)}
  /* shop by category — centered heading + centered tiles */
  #cats .sec-head{justify-content:center;text-align:center}
  #cats .sec-head>div{text-align:center;margin:0 auto}
  #cats .catgrid{justify-content:center}
</style>
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
      <a class="hslide<%= i===0?' on':'' %>" data-i="<%= i %>" href="/category/<%= c.slug %>" aria-label="Shop <%= c.name %>">
        <picture>
          <% if (bm.mobile) { %><source media="(max-width:720px)" srcset="/static/img/<%= bm.mobile %>"><% } %>
          <img src="/static/img/<%= bm.desktop || bm.mobile %>" alt="<%= c.name %>">
        </picture>
      </a>
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
<%
  var ratingRaw = String(settings.rating || '4.9');
  var deliveredRaw = String(settings.delivered || '12,000+');
  var deliveredNum = parseInt(deliveredRaw.replace(/[^0-9]/g,''), 10) || 12000;
  var deliveredSuffix = /\+/.test(deliveredRaw) ? '+' : '';
  var sinceRaw = String(settings.since || '2021');
%>
<div class="stats reveal" id="statsBand"><div class="wrap"><div class="stats-in">
  <div class="stat"><b><span class="star">★</span> <span class="gradnum" data-count="<%= ratingRaw %>">0</span></b><span class="lbl">Average customer rating</span></div>
  <div class="stat"><b><span class="gradnum" data-count="<%= deliveredNum %>" data-suffix="<%= deliveredSuffix %>">0</span></b><span class="lbl">Orders delivered</span></div>
  <div class="stat"><b>Since <span class="gradnum"><%= sinceRaw %></span></b><span class="lbl">Trusted digital store</span></div>
</div></div></div>

<!-- CATEGORY GRID -->
<section class="section reveal" id="cats">
  <div class="wrap">
    <div class="sec-head">
      <div><span class="eyebrow"><span class="dot"></span>Browse the store</span><h2>Shop by category</h2></div>
    </div>
    <div class="catgrid">
      <% cats.forEach(function(c){ %>
        <a class="cat-tile" href="/category/<%= c.slug %>" style="--g1:<%= c.g1 %>;--g2:<%= c.g2 %>">
          <span class="cg"><svg class="ic" viewBox="0 0 24 24"><%- c.icon %></svg></span>
          <span><b><%= c.name %></b></span>
        </a>
      <% }); %>
    </div>
  </div>
</section>

<!-- TRENDING -->
<% if (trending.length) { %>
<section class="section tint reveal">
  <div class="wrap">
    <div class="sec-head">
      <div><span class="eyebrow"><span class="dot"></span>Most popular right now</span><h2>Trending products</h2></div>
    </div>
    <div class="pgrid"><%- trending.map(card).join('') %></div>
  </div>
</section>
<% } %>

<!-- PER-CATEGORY SECTIONS (cards only — banners live on each category's own page) -->
<%
// rotate three distinct looks so each category reads differently: plain, tint, dark-immersive
var variants = ['', ' tint', ' dark'];
var vi = 0;
cats.forEach(function(c){
  var list = products.filter(function(p){return p.cat===c.slug;});
  if(!list.length) return;
  var look = variants[vi % variants.length]; vi++;
%>
    <section class="section reveal<%= look %>">
      <div class="wrap">
        <div class="sec-head">
          <div><span class="eyebrow"><span class="dot"></span><%= c.tag || 'Collection' %></span><h2><%= c.name %></h2></div>
          <a class="view-all" href="/category/<%= c.slug %>">View all <%= c.n %> →</a>
        </div>
        <div class="pgrid g4"><%- cardsFor(c.slug, 6) %></div>
      </div>
    </section>
<% }); %>

<!-- REVIEWS -->
<section class="section tint reveal">
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

EOF_HOME

node -e '
const ejs=require("ejs"),fs=require("fs");
try{ ejs.compile(fs.readFileSync("views/home.ejs","utf8"),{filename:"views/home.ejs"}); console.log("[ok] home.ejs compiles"); }
catch(e){ console.error("ABORT ejs",e.message); process.exit(1); }
' || exit 1
pm2 restart gsz >/dev/null 2>&1 || pm2 start server.js --name gsz >/dev/null 2>&1
sleep 2
grep -q "</html>" <<< "$(curl -fsS http://127.0.0.1:${PORT:-3900}/ 2>/dev/null || true)" && echo "[ok] home renders" || { echo "!! home failed"; false; }
trap - ERR
echo
echo "==================== STEP 37 DONE ===================="
echo " Stats bar is now its own banded section; Shop-by-Category centered;"
echo " product counts removed from category tiles."
echo "====================================================="
