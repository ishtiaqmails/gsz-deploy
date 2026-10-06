#!/usr/bin/env bash
# ============================================================
#  STEP 35: horizontal AadiFlix-style plan pills + dark-theme version toggle
#  - views/product.ejs : plans render as compact horizontal pills (wrap in a
#    row) with per-plan discount badges; Family/Adult toggle restyled for the
#    dark theme; price/painting + buy-link logic preserved.
#  Plan labels remain editable from your DB (product_plans.label). Auto-rollback.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -f "$APP/views/product.ejs" ] || { echo "ABORT: product.ejs not found"; exit 1; }
cd "$APP"
set -a; . "$APP/.env"; set +a
TS=$(date +%s); BK="$APP/.bak-step35-$TS"; mkdir -p "$BK"
cp views/product.ejs "$BK/product.ejs"
restore(){ echo "!! ROLLBACK"; cp "$BK/product.ejs" views/product.ejs 2>/dev/null||true; pm2 restart gsz >/dev/null 2>&1||true; }
trap 'restore' ERR
echo "== Step 35 (horizontal plan pills) =="

cat > views/product.ejs <<'EOF_PREJS'
<%- include('partials/store_top') %>
<style>
  /* Horizontal plan pills (AadiFlix-style), themed for the dark storefront */
  .planrow{display:flex;flex-wrap:wrap;gap:10px;margin:4px 0 16px}
  .ppill{position:relative;flex:1 1 150px;min-width:140px;max-width:230px;text-align:left;cursor:pointer;
    background:rgba(255,255,255,.035);border:1.5px solid rgba(255,255,255,.14);border-radius:14px;
    padding:13px 15px;color:inherit;font:inherit;display:flex;flex-direction:column;gap:5px;transition:.15s}
  .ppill:hover{border-color:var(--b,#2a7bff);background:rgba(255,255,255,.06)}
  .ppill.sel{border-color:var(--b,#2a7bff);background:rgba(42,123,255,.14);box-shadow:0 0 0 3px rgba(42,123,255,.2)}
  .ppill-label{font-weight:700;font-size:14px;letter-spacing:-.01em}
  .ppill-price{display:flex;align-items:baseline;gap:7px;flex-wrap:wrap}
  .ppill-now{font-weight:800;font-size:16px}
  .ppill-was{font-size:12.5px;opacity:.5;text-decoration:line-through}
  .ppill-off{position:absolute;top:-9px;right:-7px;background:linear-gradient(135deg,#16b765,#0fb858);color:#fff;
    font-size:11px;font-weight:800;padding:2px 8px;border-radius:999px;box-shadow:0 5px 14px -5px rgba(16,183,101,.85)}
  /* version chooser (Family / Adult) */
  .ptypes{margin:2px 0 16px}
  .ptypes-h{font-size:13px;font-weight:700;margin:0 0 8px;opacity:.85}
  .ptypes-opts{display:flex;gap:8px;flex-wrap:wrap}
  .ptype{appearance:none;border:1.5px solid rgba(255,255,255,.16);background:rgba(255,255,255,.035);color:inherit;
    font:inherit;font-weight:600;font-size:14px;padding:9px 16px;border-radius:10px;cursor:pointer;transition:.15s}
  .ptype:hover{border-color:var(--b,#2a7bff)}
  .ptype.on{border-color:var(--b,#2a7bff);background:rgba(42,123,255,.14);box-shadow:0 0 0 3px rgba(42,123,255,.2)}
</style>
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
      <div class="planrow" id="plans">
        <% plans.forEach(function(pl,i){ var off=(pl.old>pl.price && pl.old>0)?Math.round((1-pl.price/pl.old)*100):0; %>
          <button type="button" class="ppill<%= i===0?' sel':'' %>" data-label="<%= pl.label %>" data-types='<%- JSON.stringify(pl.types||[]) %>'>
            <% if (off>0) { %><span class="ppill-off">-<%= off %>%</span><% } %>
            <span class="ppill-label"><%= pl.label %></span>
            <span class="ppill-price"><% if (off>0) { %><span class="ppill-was" data-pkr="<%= pl.old %>"></span><% } %><span class="ppill-now" data-pkr="<%= pl.price %>"></span></span>
          </button>
        <% }); %>
      </div>
      <% } %>

      <!-- version chooser (Family / Adult etc.) — shown only when the selected plan offers it -->
      <div class="ptypes" id="ptypes" style="display:none">
        <div class="ptypes-h">Choose version</div>
        <div class="ptypes-opts" id="ptypesOpts"></div>
      </div>

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
          <% if (payNames && payNames.length) { payNames.forEach(function(nm){ %>
            <span class="pay-chip"><%= nm %></span>
          <% }); } else { %>
            <span class="pay-chip">Contact us on WhatsApp</span>
          <% } %>
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
  var plans=[].slice.call(document.querySelectorAll('.ppill'));
  var sel=plans[0]||null;
  var selType='';
  var typeBox=document.getElementById('ptypes'), typeOpts=document.getElementById('ptypesOpts');
  function renderTypes(){
    var t=[]; try{ t=JSON.parse((sel&&sel.getAttribute('data-types'))||'[]'); }catch(e){ t=[]; }
    if(!typeBox||!typeOpts) return;
    if(!t.length){ typeBox.style.display='none'; typeOpts.innerHTML=''; selType=''; return; }
    typeBox.style.display=''; typeOpts.innerHTML='';
    t.forEach(function(o,i){
      var b=document.createElement('button'); b.type='button'; b.className='ptype'+(i===0?' on':'');
      b.textContent=o.label||o.key; b.setAttribute('data-key',o.key);
      b.addEventListener('click',function(){ typeOpts.querySelectorAll('.ptype').forEach(function(x){x.classList.remove('on');}); b.classList.add('on'); selType=o.key; update(); });
      typeOpts.appendChild(b);
    });
    selType=t[0].key;
  }
  function waHref(){
    var label=sel?(sel.getAttribute('data-label')||''):'';
    var pEl=document.getElementById('pPrice'), price=pEl?pEl.textContent.trim():'';
    var msg='Hi! I want to order *'+PNAME+'*'+(label?(' — '+label):'')+(price&&price!=='—'?(' ('+price+')'):'')+'.';
    return WA ? ('https://wa.me/'+WA.replace(/[^0-9]/g,'')+'?text='+encodeURIComponent(msg)) : '#';
  }
  function syncPrice(){
    if(!sel)return;
    var curSpan=sel.querySelector('.ppill-now'), wasSpan=sel.querySelector('.ppill-was');
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
    if(buy)buy.href='/checkout?p='+encodeURIComponent(PSLUG)+'&plan='+idx+'&region='+region()+(selType?('&type='+encodeURIComponent(selType)):'');
    syncPrice();
    var h=waHref();
    var wa=document.getElementById('waBtn'); if(wa)wa.href=h;
    var wa2=document.getElementById('waBtn2'); if(wa2)wa2.href=h;
  }
  plans.forEach(function(pl){pl.addEventListener('click',function(){plans.forEach(function(x){x.classList.remove('sel');});pl.classList.add('sel');sel=pl;renderTypes();update();});});
  renderTypes();
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

EOF_PREJS

node -e '
const ejs=require("ejs"),fs=require("fs");
try{ ejs.compile(fs.readFileSync("views/product.ejs","utf8"),{filename:"views/product.ejs"}); console.log("[ok] product.ejs compiles"); }
catch(e){ console.error("ABORT ejs",e.message); process.exit(1); }
' || exit 1
pm2 restart gsz >/dev/null 2>&1 || pm2 start server.js --name gsz >/dev/null 2>&1
sleep 2
SLUG=$(psql -tA -P pager=off -h ${DB_HOST:-127.0.0.1} -p ${DB_PORT:-5432} -U $DB_USER -d $DB_NAME -c "SELECT slug FROM products WHERE active AND NOT hidden ORDER BY sort,id LIMIT 1" 2>/dev/null)
if [ -n "$SLUG" ]; then PB=$(curl -fsS "http://127.0.0.1:${PORT:-3900}/product/$SLUG" 2>/dev/null || true); grep -q "</html>" <<< "$PB" && echo "[ok] product page renders" || { echo "!! product page failed"; false; }; fi
trap - ERR
echo
echo "==================== STEP 35 DONE ===================="
echo " Plans now render as horizontal pills with discount badges."
echo "====================================================="
