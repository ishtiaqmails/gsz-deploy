#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 21: product page redesign + fixes
#  RUN: cd /opt/gsz-deploy && git pull && bash step21.sh
#   - Product page rebuilt (our dark theme + our real gateways):
#     live price with old-price + discount %, star rating, Trustpilot +
#     "Verified genuine" badge, "Guaranteed safe & secure checkout" box
#     listing Bank/JazzCash/Easypaisa/Binance/TapTap, Overview/FAQ/Reviews
#     tabs, and an "Item details" sidebar. Plan selector + Buy/WhatsApp kept.
#   - Search results now show product IMAGE + NAME only (no category).
#   - Order toss now opens the product page on click.
#  Files: views/product.ejs (rewrite), public/js/app.js (patch),
#         public/css/app.css (append PDP styles). Asset version -> v=21.
#  Auto-rollback on health-check failure.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views" ] || { echo "ABORT: $APP/views not found"; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"; : "${DB_USER:?}"; : "${DB_NAME:?}"; : "${DB_PASS:?}"
echo "== Galaxy Subz x Zayron — Step 21 (product page + fixes) · port $PORT =="
ts=$(date +%s)
PSQL(){ PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" "$@"; }
cp -a "$APP/views/product.ejs"               "$APP/views/product.ejs.bak-step21.$ts"
cp -a "$APP/public/js/app.js"                "$APP/public/js/app.js.bak-step21.$ts"
cp -a "$APP/public/css/app.css"              "$APP/public/css/app.css.bak-step21.$ts"
cp -a "$APP/views/partials/store_top.ejs"    "$APP/views/partials/store_top.ejs.bak-step21.$ts"
cp -a "$APP/views/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs.bak-step21.$ts"
restore(){
  echo ">> rolling back Step 21"
  cp -a "$APP/views/product.ejs.bak-step21.$ts"               "$APP/views/product.ejs"
  cp -a "$APP/public/js/app.js.bak-step21.$ts"                "$APP/public/js/app.js"
  cp -a "$APP/public/css/app.css.bak-step21.$ts"              "$APP/public/css/app.css"
  cp -a "$APP/views/partials/store_top.ejs.bak-step21.$ts"    "$APP/views/partials/store_top.ejs"
  cp -a "$APP/views/partials/store_bottom.ejs.bak-step21.$ts" "$APP/views/partials/store_bottom.ejs"
  pm2 restart gsz >/dev/null 2>&1 || true
}
cat > "$APP/views/product.ejs" <<'GSZ_PROD21'
<%- include('partials/store_top') %>
<% var rNum = parseFloat(rating) || 4.8; var full = Math.round(rNum); %>
<div class="wrap pdp">
  <div class="pdp-top">
    <!-- media -->
    <div class="pdp-media" id="pdpMedia">
      <% if (p.image) { %>
        <img src="/static/img/<%= p.image %>" alt="<%= p.name %>">
      <% } else { %>
        <div class="pf" style="--g1:<%= accent.g1 %>;--g2:<%= accent.g2 %>"><%= p.name %></div>
      <% } %>
    </div>
    <!-- info -->
    <div class="pdp-info">
      <div class="crumbs"><a href="/">Home</a> &nbsp;/&nbsp; <a href="/category/<%= p.cat_slug %>"><%= p.cat_name %></a></div>
      <h1><%= p.name %></h1>

      <div class="pdp-rate">
        <span class="rstars" aria-label="<%= rating %> out of 5">
          <% for(var i=0;i<5;i++){ %><svg viewBox="0 0 24 24" class="<%= i<full?'on':'' %>"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg><% } %>
        </span>
        <b><%= rating %></b><span class="rsep">·</span>
        <span class="rmut"><%= Number(orders).toLocaleString('en-US') %>+ sold</span>
      </div>

      <% if (p.short_desc) { %><p class="pdp-lead"><%= p.short_desc %></p><% } %>

      <!-- live price for the selected plan -->
      <div class="pdp-price">
        <span class="now" id="pPrice">—</span>
        <span class="was" id="pWas" style="display:none"></span>
        <span class="off" id="pOff" style="display:none"></span>
      </div>

      <% if (plans.length) { %>
      <div class="plans" id="plans">
        <% plans.forEach(function(pl,i){ %>
          <div class="plan<%= i===0?' sel':'' %>" data-label="<%= pl.label %>">
            <span class="rdo"></span>
            <span class="pl"><%= pl.label %></span>
            <span class="pp"><% if (pl.old>pl.price) { %><span class="was" data-pkr="<%= pl.old %>"></span><% } %><span data-pkr="<%= pl.price %>"></span></span>
          </div>
        <% }); %>
      </div>
      <% } %>

      <div class="buyrow">
        <a class="btn btn-primary btn-lg" id="buyBtn" href="#">Buy now</a>
        <a class="btn btn-wa btn-lg" id="waBtn" href="#" target="_blank" rel="noopener">
          <svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>Order via WhatsApp</a>
      </div>

      <!-- trust row -->
      <div class="trust">
        <span class="tp"><svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg>Rated <b><%= rating %>/5</b> on Trustpilot</span>
        <span class="vg"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/><path d="m9 12 2 2 4-4"/></svg>Verified genuine</span>
      </div>

      <!-- secure checkout + our real gateways -->
      <div class="pay-box">
        <div class="pay-hd"><svg class="ic ic-sm" viewBox="0 0 24 24"><rect x="4" y="10" width="16" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>Guaranteed safe &amp; secure checkout</div>
        <div class="pay-chips">
          <span class="pay-chip">Bank transfer</span>
          <span class="pay-chip">JazzCash</span>
          <span class="pay-chip">Easypaisa</span>
          <span class="pay-chip">Binance</span>
          <span class="pay-chip">TapTap Send</span>
        </div>
      </div>
    </div>
  </div>

  <!-- details grid: tabs + item-details sidebar -->
  <div class="pdp-grid">
    <div class="pdp-main">
      <div class="pdp-tabs" id="pdpTabs">
        <button class="ptab on" data-tab="overview" type="button">Overview</button>
        <% if (faqs.length) { %><button class="ptab" data-tab="faq" type="button">FAQ</button><% } %>
        <button class="ptab" data-tab="reviews" type="button">Reviews</button>
      </div>

      <div class="ptab-panel on" data-panel="overview">
        <% if (p.long_desc && p.long_desc.trim()) { %>
          <div class="longdesc"><%= p.long_desc %></div>
        <% } else { %>
          <p class="longdesc"><%= p.short_desc || (p.name + ' — premium, delivered fast and backed by real WhatsApp support.') %></p>
        <% } %>
        <ul class="feat">
          <li><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M20 6 9 17l-5-5"/></svg>Instant automated delivery to email &amp; WhatsApp</li>
          <li><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M20 6 9 17l-5-5"/></svg>Verified before we deliver — no guesswork</li>
          <li><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M20 6 9 17l-5-5"/></svg>Works across all your devices</li>
          <li><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M20 6 9 17l-5-5"/></svg>Real support &amp; replacements on WhatsApp</li>
        </ul>
      </div>

      <% if (faqs.length) { %>
      <div class="ptab-panel" data-panel="faq">
        <div class="faq">
          <% faqs.forEach(function(f){ %><details><summary><%= f.q %></summary><p><%= f.a %></p></details><% }); %>
        </div>
      </div>
      <% } %>

      <div class="ptab-panel" data-panel="reviews">
        <div class="rev-summary">
          <div class="rev-big"><b><%= rating %></b><span>/ 5</span>
            <span class="rstars sm"><% for(var k=0;k<5;k++){ %><svg viewBox="0 0 24 24" class="<%= k<full?'on':'' %>"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg><% } %></span>
          </div>
          <p class="rmut">Based on <%= Number(orders).toLocaleString('en-US') %>+ verified orders. Real reviews are collected from customers after delivery.</p>
          <a class="btn btn-ghost" href="/#reviews">See customer reviews →</a>
        </div>
      </div>
    </div>

    <aside class="idetails">
      <h3>Item details</h3>
      <div class="idrow"><span>Rating</span><b><span class="star">★</span> <%= rating %></b></div>
      <div class="idrow"><span>Sold</span><b><%= Number(orders).toLocaleString('en-US') %>+</b></div>
      <% if (p.delivery) { %><div class="idrow"><span>Delivery</span><b><%= p.delivery %></b></div><% } %>
      <div class="idrow"><span>Category</span><b><a href="/category/<%= p.cat_slug %>" style="color:var(--b)"><%= p.cat_name %></a></b></div>
      <a class="btn btn-wa" style="width:100%;margin-top:14px" href="#" id="waBtn2" target="_blank" rel="noopener">
        <svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>Ask before you buy</a>
    </aside>
  </div>

  <% if (similar.length) { %>
  <section class="pdp-sec">
    <div class="sec-head"><div><span class="eyebrow"><span class="dot"></span>You may also like</span><h2>More in <%= p.cat_name %></h2></div>
      <a class="view-all" href="/category/<%= p.cat_slug %>">View all →</a></div>
    <div class="pgrid">
      <% similar.forEach(function(s){ %>
        <a class="pcard" href="/product/<%= s.slug %>">
          <% if (s.image) { %><img class="pimg" loading="lazy" src="/static/img/<%= s.image %>" alt="<%= s.name %>">
          <% } else { %><div class="pfallback" style="--g1:<%= accent.g1 %>;--g2:<%= accent.g2 %>"><span><%= s.name %></span></div><% } %>
          <div class="pbody"><div class="pname"><%= s.name %></div><div class="pdesc"><%= s.descr %></div>
            <div class="pfoot"><% if (s.plans>1) { %><span class="pfrom">Starts from</span><% } %><span class="pprice" data-pkr="<%= s.from %>"></span></div>
          </div>
        </a>
      <% }); %>
    </div>
  </section>
  <% } %>
</div>

<script>
(function(){
  var PSLUG=<%- JSON.stringify(p.slug) %>, PNAME=<%- JSON.stringify(p.name) %>, WA=<%- JSON.stringify(waNumber) %>;
  function region(){try{return localStorage.getItem('gsz_region')||'PK';}catch(e){return 'PK';}}
  var plans=[].slice.call(document.querySelectorAll('.plan'));
  var sel=plans[0]||null;
  function waHref(){
    var label=sel?(sel.getAttribute('data-label')||''):'';
    var pEl=document.getElementById('pPrice'), price=pEl?pEl.textContent.trim():'';
    var msg='Hi! I want to order *'+PNAME+'*'+(label?(' — '+label):'')+(price&&price!=='—'?(' ('+price+')'):'')+'.';
    return WA ? ('https://wa.me/'+WA.replace(/[^0-9]/g,'')+'?text='+encodeURIComponent(msg)) : '#';
  }
  function syncPrice(){
    if(!sel)return;
    var pp=sel.querySelector('.pp'); if(!pp)return;
    var spans=pp.querySelectorAll('span'); var curSpan=spans[spans.length-1];
    var wasSpan=pp.querySelector('.was');
    var pEl=document.getElementById('pPrice'); if(pEl&&curSpan)pEl.textContent=curSpan.textContent||'—';
    var wEl=document.getElementById('pWas');
    if(wEl){ if(wasSpan&&wasSpan.textContent){wEl.textContent=wasSpan.textContent;wEl.style.display='';}else{wEl.style.display='none';} }
    var off=document.getElementById('pOff');
    if(off){
      var oldp=wasSpan?parseFloat(wasSpan.getAttribute('data-pkr')):0;
      var newp=curSpan?parseFloat(curSpan.getAttribute('data-pkr')):0;
      if(oldp>newp&&oldp>0){off.textContent='-'+Math.round((1-newp/oldp)*100)+'%';off.style.display='';}else{off.style.display='none';}
    }
  }
  function update(){
    var idx=sel?plans.indexOf(sel):0;
    var buy=document.getElementById('buyBtn');
    if(buy)buy.href='/checkout?p='+encodeURIComponent(PSLUG)+'&plan='+idx+'&region='+region();
    syncPrice();
    var h=waHref();
    var wa=document.getElementById('waBtn'); if(wa)wa.href=h;
    var wa2=document.getElementById('waBtn2'); if(wa2)wa2.href=h;
  }
  plans.forEach(function(pl){pl.addEventListener('click',function(){plans.forEach(function(x){x.classList.remove('sel');});pl.classList.add('sel');sel=pl;update();});});
  // tabs
  var tabs=[].slice.call(document.querySelectorAll('.ptab'));
  tabs.forEach(function(t){t.addEventListener('click',function(){
    tabs.forEach(function(x){x.classList.remove('on');}); t.classList.add('on');
    var key=t.getAttribute('data-tab');
    [].slice.call(document.querySelectorAll('.ptab-panel')).forEach(function(pn){pn.classList.toggle('on',pn.getAttribute('data-panel')===key);});
  });});
  // prices are painted by app.js shortly after load
  update(); setTimeout(update, 300); setTimeout(update, 800);
})();
</script>

<%- include('partials/store_bottom') %>

GSZ_PROD21

cat > /tmp/gsz21_appjs.js <<'GSZ_APPJS21'
const fs=require('fs');const f=process.argv[2];let s=fs.readFileSync(f,'utf8');let fail=0;
function rep(a,b,l){const n=s.split(a).length-1;if(n!==1){console.error('FAIL ['+l+'] matches='+n);fail=1;return;}s=s.replace(a,b);console.log('ok '+l);}

// 1) search results: product image + name only (drop category .mt line)
rep("'<span><span class=\"nm\">'+p.name+'</span><span class=\"mt\">'+(p.catName||p.cat||'')+'</span></span>'+",
    "'<span><span class=\"nm\">'+p.name+'</span></span>'+",
    'search no category');

// 2) toss: store product URL on a data attribute (works for <button>)
rep("el.href='/product/'+p.slug; el.style.display='flex';",
    "el.dataset.href='/product/'+p.slug; el.style.display='flex';",
    'toss data-href');

// 3) toss click -> navigate to the product (X still dismisses)
rep("var toss=$('#toss'); if(toss)toss.addEventListener('click',function(e){if(e.target.closest('.tx')){e.preventDefault();toss.classList.remove('on');}});",
    "var toss=$('#toss'); if(toss)toss.addEventListener('click',function(e){if(e.target.closest('.tx')){e.preventDefault();e.stopPropagation();toss.classList.remove('on');return;}var h=toss.dataset.href;if(h)window.location=h;});",
    'toss click nav');

if(fail){console.error('APPJS PATCH FAILED');process.exit(1);}
fs.writeFileSync(f,s);console.log('[ok] app.js patched');

GSZ_APPJS21
node /tmp/gsz21_appjs.js "$APP/public/js/app.js" || { restore; exit 1; }

cat > /tmp/gsz21_pdp.css <<'GSZ_PDPCSS21'

/* ============================================================
   PDP R2 — rating, price, trust, gateways, tabs, item details
   ============================================================ */
.pdp-rate{display:flex;align-items:center;gap:8px;margin:0 0 14px;color:var(--muted);font-size:14px}
.pdp-rate b{color:var(--ink)}
.pdp-rate .rsep{opacity:.5}
.rstars{display:inline-flex;gap:2px}
.rstars svg{width:17px;height:17px;fill:#3a4061;stroke:none}
.rstars svg.on{fill:#f5b301}
.rstars.sm svg{width:15px;height:15px}
.pdp-price{display:flex;align-items:baseline;gap:12px;flex-wrap:wrap;margin:4px 0 20px}
.pdp-price .now{font-family:var(--display);font-weight:800;font-size:clamp(30px,4vw,40px);letter-spacing:-.02em;
  background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent}
.pdp-price .was{color:var(--muted);text-decoration:line-through;font-size:18px;font-weight:600}
.pdp-price .off{background:rgba(42,209,127,.16);color:#2ad17f;font-weight:800;font-size:13px;border-radius:999px;padding:4px 10px}
.trust{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin:18px 0 0;font-size:13.5px;color:var(--ink-soft)}
.trust b{color:var(--ink)}
.trust .tp{display:inline-flex;align-items:center;gap:7px}
.trust .tp svg{width:17px;height:17px;fill:#12b26a;stroke:none}
.trust .vg{display:inline-flex;align-items:center;gap:6px;color:var(--ok)}
.pay-box{margin-top:16px;border:1px solid var(--line);border-radius:14px;background:var(--surface);padding:14px 16px}
.pay-hd{display:flex;align-items:center;gap:8px;font-size:12.5px;font-weight:700;letter-spacing:.02em;color:var(--muted);text-transform:uppercase;margin-bottom:11px}
.pay-hd svg{color:var(--ok)}
.pay-chips{display:flex;gap:8px;flex-wrap:wrap}
.pay-chip{font-size:12.5px;font-weight:700;color:var(--ink-soft);background:var(--wash);border:1px solid var(--line-2);border-radius:9px;padding:7px 12px}
/* details grid */
.pdp-grid{display:grid;grid-template-columns:1fr 320px;gap:24px;padding:clamp(26px,4vw,44px) 0;border-top:1px solid var(--line);margin-top:clamp(26px,4vw,44px)}
@media(max-width:900px){.pdp-grid{grid-template-columns:1fr}}
.pdp-tabs{display:flex;gap:6px;border-bottom:1px solid var(--line);margin-bottom:22px;flex-wrap:wrap}
.ptab{background:none;border:0;color:var(--muted);font-weight:700;font-size:15px;padding:10px 14px;cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-1px}
.ptab:hover{color:var(--ink)}
.ptab.on{color:var(--ink);border-bottom-color:var(--b)}
.ptab-panel{display:none}
.ptab-panel.on{display:block;animation:fade .25s ease}
.feat{display:grid;gap:10px;margin:18px 0 0}
.feat li{display:flex;align-items:flex-start;gap:10px;color:var(--ink-soft);font-size:14.5px;line-height:1.5}
.feat li svg{color:var(--ok);flex:none;margin-top:2px}
.rev-summary{display:flex;flex-direction:column;align-items:flex-start;gap:12px}
.rev-big{display:flex;align-items:baseline;gap:8px}
.rev-big b{font-family:var(--display);font-weight:800;font-size:44px;letter-spacing:-.02em;line-height:1}
.rev-big span{color:var(--muted);font-weight:600}
.idetails{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:22px;align-self:start;position:sticky;top:92px}
.idetails h3{font-family:var(--display);font-weight:800;font-size:17px;margin:0 0 14px}
.idrow{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 0;border-top:1px solid var(--line);font-size:14px;color:var(--muted)}
.idrow:first-of-type{border-top:0}
.idrow b{color:var(--ink);font-weight:700}
.idrow .star{color:#f5b301}

GSZ_PDPCSS21
node -e 'const fs=require("fs");const a="/opt/gsz/public/css/app.css";let s=fs.readFileSync(a,"utf8");if(s.indexOf("PDP R2")===-1){s+=fs.readFileSync("/tmp/gsz21_pdp.css","utf8");fs.writeFileSync(a,s);console.log("[ok] PDP styles appended");}else{console.log("[ok] PDP styles already present");}' || { restore; exit 1; }

cat > /tmp/gsz21_bump.js <<'GSZ_B21'
const fs=require('fs');
['/opt/gsz/views/partials/store_top.ejs','/opt/gsz/views/partials/store_bottom.ejs'].forEach(function(f){
  let s=fs.readFileSync(f,'utf8');s=s.replace(/(app\.(?:css|js))\?v=\d+/g,'$1?v=21');fs.writeFileSync(f,s);
});
console.log('[ok] asset version -> v=21');
GSZ_B21
node /tmp/gsz21_bump.js || { restore; exit 1; }
echo "[ok] files written"

pm2 restart gsz --update-env >/dev/null
sleep 2
OKALL=1
SLUG=$(PSQL -tAc "SELECT slug FROM products ORDER BY sort,id LIMIT 1" | tr -d '[:space:]')
HEALTH=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health")
HOME_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/")
PP=$(curl -fsS "http://127.0.0.1:$PORT/product/$SLUG" || true)
HB=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
JS=$(curl -fsS "http://127.0.0.1:$PORT/static/js/app.js?v=21" || true)
CSS=$(curl -fsS "http://127.0.0.1:$PORT/static/css/app.css?v=21" || true)
[ "$HEALTH" = "200" ]                   || { echo "FAIL: health $HEALTH"; OKALL=0; }
[ "$HOME_CODE" = "200" ]                 || { echo "FAIL: home $HOME_CODE"; OKALL=0; }
grep -q 'pay-chip'      <<< "$PP"        || { echo "FAIL: product gateways missing"; OKALL=0; }
grep -q 'id="pPrice"'   <<< "$PP"        || { echo "FAIL: product price block missing"; OKALL=0; }
grep -q 'class="ptab '  <<< "$PP"        || { echo "FAIL: product tabs missing"; OKALL=0; }
grep -q 'dataset.href'  <<< "$JS"        || { echo "FAIL: toss nav not applied"; OKALL=0; }
if grep -q 'class="mt"' <<< "$JS"; then echo "FAIL: search still shows category"; OKALL=0; fi
grep -q 'PDP R2'        <<< "$CSS"       || { echo "FAIL: PDP css not served"; OKALL=0; }
grep -q 'app.css?v=21'  <<< "$HB"        || { echo "FAIL: version not bumped"; OKALL=0; }
if [ "$OKALL" != "1" ]; then echo "CHECK FAILED — rolling back"; restore; pm2 logs gsz --lines 20 --nostream || true; exit 1; fi
echo "============================================================"
echo "  STEP 21 OK — hard-refresh once (Ctrl+Shift+R)"
echo "  - Product page redesigned (dark theme, our gateways, tabs, details)."
echo "  - Search: image + name only (no category)."
echo "  - Order toss opens the product on click."
echo "============================================================"
