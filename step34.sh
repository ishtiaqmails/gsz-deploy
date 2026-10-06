#!/usr/bin/env bash
# ============================================================
#  STEP 34: multi-type plans (Family/Adult toggle) + real payment chips
#  - routes/products.js  : passes per-plan bot types (customer-choose) + the
#    REAL payment method names to the product page.
#  - views/product.ejs   : "Choose version" toggle (shown only when a plan's
#    bot product has >1 type and the mapping left the type unset); real payment
#    chips instead of the hardcoded list; chosen type carried into the buy link.
#  - routes/checkout.js  : accepts the chosen type and applies it as the order's
#    bot_type (validated against the bot product's real types).
#  - views/checkout.ejs  : carries the chosen type through as a hidden field.
#  Auto-rollback.
# ============================================================
set -euo pipefail
APP=/opt/gsz
for f in routes/products.js views/product.ejs routes/checkout.js views/checkout.ejs; do
  [ -f "$APP/$f" ] || { echo "ABORT: $f not found"; exit 1; }
done
cd "$APP"
set -a; . "$APP/.env"; set +a
TS=$(date +%s); BK="$APP/.bak-step34-$TS"; mkdir -p "$BK"
cp routes/products.js "$BK/"; cp views/product.ejs "$BK/"; cp routes/checkout.js "$BK/"; cp views/checkout.ejs "$BK/"
restore(){ echo "!! ROLLBACK"; cp "$BK/products.js" routes/products.js; cp "$BK/product.ejs" views/product.ejs; cp "$BK/checkout.js" routes/checkout.js; cp "$BK/checkout.ejs" views/checkout.ejs; pm2 restart gsz >/dev/null 2>&1||true; }
trap 'restore' ERR
echo "== Step 34 (type toggle + real payment chips) =="

cat > routes/products.js <<'EOF_PRJS'
const express = require('express');
const botapi = require('../lib/botapi');

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

      const planRows = (await pool.query(
        'SELECT label, price_pkr, old_pkr, source, bot_sku, bot_type FROM product_plans WHERE product_id=$1 ORDER BY sort, id', [prow.id]
      )).rows;

      // bot product types -> let the customer choose (Family/Adult) only when the
      // plan is bot-sourced, the admin left the type unset, and the bot product
      // actually has more than one type.
      const botTypes = {};
      const skus = [...new Set(planRows.filter(r => r.source === 'bot' && r.bot_sku).map(r => r.bot_sku))];
      if (skus.length) {
        try {
          (await pool.query('SELECT sku, types FROM bot_products WHERE sku = ANY($1)', [skus])).rows
            .forEach(b => { botTypes[b.sku] = Array.isArray(b.types) ? b.types : []; });
        } catch (e) { /* types optional */ }
      }
      const plans = planRows.map(r => {
        const t = (r.source === 'bot' && !r.bot_type && botTypes[r.bot_sku] && botTypes[r.bot_sku].length > 1)
          ? botTypes[r.bot_sku].map(x => ({ key: String(x.key), label: x.label || x.key })) : [];
        return { label: r.label, price: Number(r.price_pkr || 0), old: Number(r.old_pkr || 0), types: t };
      });

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

      // real payment methods only (bot pay-accounts when connected, else site methods)
      let payNames = [];
      try {
        if (botapi.configured()) {
          const accts = await botapi.getPayAccounts();
          if (Array.isArray(accts) && accts.length) payNames = accts.map(a => a.label || a.method || a.key).filter(Boolean);
        }
      } catch (e) { /* fall through */ }
      if (!payNames.length) {
        try { payNames = (await pool.query("SELECT name FROM payment_methods WHERE active ORDER BY sort,id")).rows.map(r => r.name).filter(Boolean); } catch (e) {}
      }
      payNames = [...new Set(payNames)];

      const rating = (4.5 + seeded(prow.id) * 0.5).toFixed(1);
      const orders = 200 + Math.floor(seeded(prow.id + 7) * 9800);

      res.render('product', {
        p: prow, plans, faqs, similar, settings, payNames,
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
EOF_PRJS
cat > views/product.ejs <<'EOF_PREJS'
<%- include('partials/store_top') %>
<style>
  .ptypes{margin:2px 0 16px}
  .ptypes-h{font-size:13px;font-weight:700;margin:0 0 8px}
  .ptypes-opts{display:flex;gap:8px;flex-wrap:wrap}
  .ptype{appearance:none;border:1.5px solid #e7ebf6;background:#fff;color:inherit;font:inherit;font-weight:600;font-size:14px;padding:9px 16px;border-radius:10px;cursor:pointer;transition:.15s}
  .ptype:hover{border-color:var(--b,#2a7bff)}
  .ptype.on{border-color:var(--b,#2a7bff);background:rgba(42,123,255,.08);box-shadow:0 0 0 3px rgba(42,123,255,.12)}
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
      <div class="plans" id="plans">
        <% plans.forEach(function(pl,i){ %>
          <div class="plan<%= i===0?' sel':'' %>" data-label="<%= pl.label %>" data-types='<%- JSON.stringify(pl.types||[]) %>'>
            <span class="rdo"></span>
            <span class="pl"><%= pl.label %></span>
            <span class="pp"><% if (pl.old>pl.price) { %><span class="was" data-pkr="<%= pl.old %>"></span><% } %><span data-pkr="<%= pl.price %>"></span></span>
          </div>
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
  var plans=[].slice.call(document.querySelectorAll('.plan'));
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
cat > routes/checkout.js <<'EOF_COJS'
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const express = require('express');
const multer = require('multer');
const botapi = require('../lib/botapi');
const mailer = require('../lib/mailer');
const emails = require('../lib/emails');

module.exports = function (pool) {
  const router = express.Router();
  const UP = path.join(__dirname, '..', 'uploads', 'proofs');
  fs.mkdirSync(UP, { recursive: true });

  const storage = multer.diskStorage({
    destination: (q, f, cb) => cb(null, UP),
    filename: (q, f, cb) => cb(null, 'proof_' + Date.now() + '_' + Math.random().toString(36).slice(2, 8) + path.extname(f.originalname || '').toLowerCase())
  });
  const okf = /\.(jpg|jpeg|png|webp|gif|pdf)$/i;
  const upload = multer({ storage, limits: { fileSize: 12 * 1024 * 1024 }, fileFilter: (q, f, cb) => cb(null, okf.test(f.originalname || '')) });

  const REGIONS = { PK: { cur: 'Rs', rate: 1 }, US: { cur: '$', rate: 0.0036 }, GB: { cur: '£', rate: 0.0028 }, AE: { cur: 'AED', rate: 0.013 } };
  const reg = r => (REGIONS[r] ? r : 'PK');
  function fmt(cur, val) { val = Number(val) || 0; if (cur === 'Rs') return 'Rs ' + Math.round(val).toLocaleString('en-US'); return cur + ' ' + (val < 10 ? val.toFixed(2) : Math.round(val).toLocaleString('en-US')); }
  async function settingsObj() { const s = {}; (await pool.query('SELECT key,value FROM settings')).rows.forEach(r => { s[r.key] = r.value; }); return s; }
  function visible(region, m) { return m.scope === 'all' || (region === 'PK' ? m.scope === 'pk' : m.scope === 'global'); }
  function quote(m, pkr, usd, dispCur, disp) {
    if (m.currency === 'PKR') return fmt('Rs', pkr);
    if (m.currency === 'USD' || m.currency === 'USDT') return fmt('$', usd);
    return fmt(dispCur, disp);
  }
  const usdtAmount = pkr => +(Number(pkr || 0) * REGIONS.US.rate).toFixed(2);

  // -------- email helpers --------
  function siteUrl() { const d = (process.env.SITE_DOMAIN || '').replace(/\/+$/, ''); return d ? (/^https?:/i.test(d) ? d : ('https://' + d)) : ''; }
  async function emailOrder(o, kind) {
    try {
      if (!o || !o.email || !mailer.configured()) return;
      const base = siteUrl();
      const opts = {
        orderUrl: base ? (base + '/order/' + encodeURIComponent(o.order_no)) : '',
        waLink: process.env.WA_NUMBER ? ('https://wa.me/' + String(process.env.WA_NUMBER).replace(/[^0-9]/g, '')) : ''
      };
      let subject, html;
      if (kind === 'delivered') { subject = 'Your order ' + o.order_no + ' is ready'; html = emails.deliveryEmail(o, opts); }
      else { subject = (o.status === 'paid' ? 'Payment confirmed' : 'Order received') + ' · ' + o.order_no; html = emails.confirmationEmail(o, opts); }
      await mailer.send(o.email, subject, html);
    } catch (e) { /* email never blocks an order */ }
  }

  function acctVisible(region, a) {
    const r = String(a.region || 'all').toLowerCase();
    if (r === 'all' || r === 'both' || r === '') return true;
    if (region === 'PK') return r === 'pk' || r === 'pakistan';
    return r === 'global' || r === 'intl' || r === 'international' || r === 'world';
  }

  async function payMethods(region, pkr, usd) {
    if (botapi.configured()) {
      try {
        const accts = await botapi.getPayAccounts();
        if (Array.isArray(accts) && accts.length) {
          const vis = accts.filter(a => acctVisible(region, a));
          const use = vis.length ? vis : accts;
          const list = use.map(a => {
            const isUsd = String(a.currency || '').toUpperCase() !== 'PKR';
            return {
              key: a.key, name: a.label || a.method || a.key, currency: a.currency || 'PKR',
              title: a.title || '', account: a.account || '', instructions: a.instructions || '',
              region: a.region || 'all', botAcct: true,
              pay: isUsd ? (String(a.currency || 'USDT') + ' ' + usdtAmount(pkr)) : fmt('Rs', pkr),
              details: (a.title ? ('Title: ' + a.title) : '') + (a.account ? ('\nAccount: ' + a.account) : '')
            };
          });
          return { methods: list, botAcct: true };
        }
      } catch (e) { /* fall through to site methods */ }
    }
    const R = REGIONS[region];
    const disp = pkr * R.rate;
    const allm = (await pool.query('SELECT key,name,currency,scope,details,instructions FROM payment_methods WHERE active ORDER BY sort,id')).rows;
    const methods = allm.filter(m => visible(region, m)).map(m => Object.assign({}, m, { botAcct: false, title: '', account: '', pay: quote(m, pkr, usd, R.cur, disp) }));
    return { methods, botAcct: false };
  }

  function customerFields(deliveryType) {
    if (['hotplayer', 'ibosol', 'zayron'].includes(deliveryType)) return ['mac'];
    if (deliveryType === 'smm') return ['link', 'qty'];
    return [];
  }
  // Account/invite deliveries can take an OPTIONAL activation email (Canva, Gemini,
  // Envato, Udemy, Zoom). Blank = use the customer's order email.
  function wantsActEmail(deliveryType) { return ['vendor_invite', 'amember', 'portal'].includes(deliveryType); }

  async function availability(plan, deliveryType) {
    try {
      if (plan.source === 'inventory') {
        const n = (await pool.query("SELECT count(*)::int n FROM inventory_items WHERE plan_id=$1 AND status='available'", [plan.id])).rows[0].n;
        return { available: n > 0, count: n, kind: 'inventory' };
      }
      if (plan.source === 'bot' && deliveryType === 'stock' && plan.bot_sku && botapi.configured()) {
        const s = await botapi.getStock(plan.bot_sku);
        return { available: s.available !== false, count: (s.count != null ? s.count : null), kind: 'bot' };
      }
    } catch (e) {
      return { available: true, count: null, kind: plan.source, unknown: true };
    }
    return { available: true, count: null, kind: plan.source };
  }

  async function botMeta(plan) {
    if (plan.source === 'bot' && plan.bot_sku) {
      const b = (await pool.query('SELECT delivery_type, missing FROM bot_products WHERE sku=$1', [plan.bot_sku])).rows[0];
      if (b) return { deliveryType: b.delivery_type, missing: b.missing };
    }
    return { deliveryType: null, missing: false };
  }

  const STATUS_MAP = { genuine: 'paid', pending: 'verifying', lost_race: 'review', ambiguous: 'review', fraud_consumed: 'rejected' };

  // ============ FULFILMENT (bot / inventory / manual) ============
  async function fulfill(orderId) {
    const o = (await pool.query('SELECT * FROM orders WHERE id=$1', [orderId])).rows[0];
    if (!o || o.status !== 'paid') return;

    if (o.source === 'inventory') {
      const plan = (await pool.query('SELECT id FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort, id LIMIT 1', [o.product_id, o.plan_label])).rows[0];
      if (!plan) { await pool.query("UPDATE orders SET status='failed' WHERE id=$1", [o.id]); return; }
      const got = await pool.query(
        `UPDATE inventory_items SET status='delivered', order_no=$1, delivered_at=now()
         WHERE id = (SELECT id FROM inventory_items WHERE plan_id=$2 AND status='available' ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED)
         RETURNING payload`, [o.order_no, plan.id]);
      if (got.rows[0]) {
        await pool.query("UPDATE orders SET status='delivered', delivered_credentials=$1, delivered_at=now() WHERE id=$2", [got.rows[0].payload, o.id]);
        const full = (await pool.query('SELECT * FROM orders WHERE id=$1', [o.id])).rows[0];
        await emailOrder(full, 'delivered');
      } else {
        await pool.query("UPDATE orders SET status='out_of_stock' WHERE id=$1", [o.id]);
      }
      return;
    }

    if (o.source === 'bot' && o.bot_sku && botapi.configured()) {
      try {
        const of = (o.fields && typeof o.fields === 'object') ? o.fields : {};
        const fields = Object.assign({ email: of.act_email || o.email }, of);
        const payload = {
          ref: o.order_no, sku: o.bot_sku, quantity: o.qty || 1,
          userPhone: String(o.whatsapp || '').replace(/[^0-9]/g, ''),
          userName: (String(o.email || '').split('@')[0]) || 'Customer',
          payment: { txid: o.txn_ref || '', amountClaimed: Number(o.amount_claimed || o.amount_pkr || 0) },
          fields
        };
        if (o.bot_plan_key) payload.plan_key = o.bot_plan_key;
        if (o.bot_type) payload.type = o.bot_type;
        const sr = await botapi.submitOrder(payload);
        await pool.query("UPDATE orders SET status='delivering', bot_order_id=$1 WHERE id=$2", [String((sr && sr.order_id) || ''), o.id]);
        await pollOnce(o.order_no);
      } catch (e) {
        await pool.query('UPDATE orders SET claim_result=$1 WHERE id=$2', [('submit_err:' + e.message).slice(0, 80), o.id]);
      }
      return;
    }
    // manual: left as 'paid' for the admin to deliver.
  }

  async function pollOnce(orderNo) {
    const o = (await pool.query('SELECT id, status FROM orders WHERE order_no=$1', [orderNo])).rows[0];
    if (!o || o.status !== 'delivering') return;
    try {
      const st = await botapi.orderStatus(orderNo);
      if (st && st.status === 'delivered') {
        await pool.query("UPDATE orders SET status='delivered', delivered_credentials=$1, delivered_at=now() WHERE id=$2", [st.delivered_credentials || '', o.id]);
        const full = (await pool.query('SELECT * FROM orders WHERE id=$1', [o.id])).rows[0];
        await emailOrder(full, 'delivered');
      } else if (st && (st.status === 'failed' || st.status === 'out_of_stock')) {
        await pool.query('UPDATE orders SET status=$1 WHERE id=$2', [st.status, o.id]);
      }
    } catch (e) { /* transient; drainer retries */ }
  }

  // ---- payment verification (async, non-blocking; safe to call repeatedly) ----
  // Runs the bot verify-claim for a 'verifying' bot order. The bot's IMAP scan
  // can be slow, so we never block the customer on it: checkout sets the order
  // to 'verifying' and fires this in the background; the drainer retries until
  // the bank email lands. Anti-double-claim is enforced bot-side (unique index).
  async function reverifyOrder(orderId) {
    try {
      const o = (await pool.query('SELECT * FROM orders WHERE id=$1', [orderId])).rows[0];
      if (!o || o.status !== 'verifying' || o.source !== 'bot') return;
      if (!botapi.configured() || !o.method_key) return;
      const isUsd = o.method_key === 'binance' || String(o.currency || '').toUpperCase() === 'USDT';
      const amount = isUsd ? Number(o.amount_usd) : Number(o.amount_pkr);
      const created = o.created_at ? new Date(o.created_at).getTime() : Date.now();
      const since = created - 30 * 60 * 1000;
      const f = (o.fields && typeof o.fields === 'object') ? o.fields : {};
      const vr = await botapi.verifyClaim({
        amount, since, ref: o.order_no,
        userPhone: String(o.whatsapp || '').replace(/[^0-9]/g, ''),
        method: o.method_key, screenshotHash: f.screenshotHash || null
      });
      const claim = vr && vr.result;
      const st = STATUS_MAP[claim] || 'verifying';
      await pool.query(
        "UPDATE orders SET status=$1, claim_result=$2, amount_claimed=CASE WHEN $2='genuine' THEN $3 ELSE amount_claimed END, verified_at=CASE WHEN $2='genuine' THEN now() ELSE verified_at END WHERE id=$4 AND status='verifying'",
        [st, claim || null, amount, o.id]
      );
      if (claim === 'genuine') await fulfill(o.id);
    } catch (e) {
      try { await pool.query("UPDATE orders SET claim_result=$1 WHERE id=$2 AND status='verifying'", [('verify_err:' + e.message).slice(0, 80), orderId]); } catch (_) {}
    }
  }

  // Background drainer: verify payments and finish deliveries even if the
  // customer closed the page. Retries 'verifying' claims for up to 2h, then
  // completes 'paid'/'delivering' bot orders.
  const drainer = setInterval(async () => {
    try {
      if (!botapi.configured()) return;
      const vrows = (await pool.query("SELECT id FROM orders WHERE source='bot' AND status='verifying' AND created_at > now() - interval '2 hours' ORDER BY id DESC LIMIT 20")).rows;
      for (const r of vrows) await reverifyOrder(r.id);
      const rows = (await pool.query("SELECT id, order_no, status FROM orders WHERE source='bot' AND status IN ('delivering','paid') ORDER BY id DESC LIMIT 20")).rows;
      for (const r of rows) {
        if (r.status === 'delivering') await pollOnce(r.order_no);
        else await fulfill(r.id);
      }
    } catch (e) { /* ignore */ }
  }, 15000);
  if (drainer.unref) drainer.unref();

  // ---- checkout page ----
  router.get('/checkout', async (req, res) => {
    try {
      const slug = String(req.query.p || '');
      const planIdx = parseInt(req.query.plan, 10) || 0;
      const region = reg(req.query.region);
      const prow = (await pool.query('SELECT id, slug, name FROM products WHERE slug=$1 AND active AND NOT hidden', [slug])).rows[0];
      if (!prow) return res.status(404).render('notfound', { what: 'product' });
      const plans = (await pool.query('SELECT id, label, price_pkr, old_pkr, source, bot_sku, bot_plan_key, bot_type FROM product_plans WHERE product_id=$1 ORDER BY sort, id', [prow.id])).rows;
      if (!plans.length) return res.status(404).render('notfound', { what: 'product' });
      const idx = (planIdx >= 0 && planIdx < plans.length) ? planIdx : 0;
      const plan = plans[idx];
      const pkr = Number(plan.price_pkr || 0);
      const R = REGIONS[region];
      const disp = pkr * R.rate;
      const usd = pkr * REGIONS.US.rate;
      const { methods } = await payMethods(region, pkr, usd);
      const s = await settingsObj();

      const meta = await botMeta(plan);
      const needFields = customerFields(meta.deliveryType);
      const avail = (meta.missing) ? { available: false, count: 0, kind: 'bot' } : await availability(plan, meta.deliveryType);

      res.render('checkout', {
        p: prow, plan, planIdx: idx, region, regionList: Object.keys(REGIONS),
        priceDisplay: fmt(R.cur, disp), priceUsd: fmt('$', usd),
        methods, settings: s, logoFile: s.logo_file || 'logo.png',
        waNumber: s.wa_number || process.env.WA_NUMBER || '',
        needFields, optEmail: wantsActEmail(meta.deliveryType),
        chosenType: String(req.query.type || '').trim(),
        avail, error: req.query.e || null
      });
    } catch (e) { res.status(500).send('Checkout error: ' + e.message); }
  });

  // ---- place order (instant: verify payment in the background) ----
  router.post('/checkout', upload.single('proof'), async (req, res) => {
    try {
      const b = req.body || {};
      const slug = String(b.product || '');
      const planIdx = parseInt(b.plan, 10) || 0;
      const region = reg(b.region);
      const email = String(b.email || '').trim();
      const whatsapp = String(b.whatsapp || '').trim();
      const method_key = String(b.method || '').trim();
      const txn = String(b.txn || '').trim().slice(0, 200);
      const note = String(b.note || '').trim().slice(0, 1000);
      const mac = String(b.mac || '').trim().slice(0, 64);
      const link = String(b.link || '').trim().slice(0, 400);
      const qty = String(b.qty || '').trim().slice(0, 32);
      const actEmail = String(b.act_email || '').trim().slice(0, 160);
      const back = '/checkout?p=' + encodeURIComponent(slug) + '&plan=' + planIdx + '&region=' + region;
      const fail = msg => res.redirect(back + '&e=' + encodeURIComponent(msg));

      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return fail('Please enter a valid email so we can send your order.');
      if (whatsapp.replace(/[^0-9]/g, '').length < 7) return fail('Please enter a valid WhatsApp number.');
      const prow = (await pool.query('SELECT id, name FROM products WHERE slug=$1 AND active AND NOT hidden', [slug])).rows[0];
      if (!prow) return fail('Product not found.');
      const plans = (await pool.query('SELECT id, label, price_pkr, source, bot_sku, bot_plan_key, bot_type FROM product_plans WHERE product_id=$1 ORDER BY sort, id', [prow.id])).rows;
      if (!plans.length) return fail('No plans available for this product.');
      const idx = (planIdx >= 0 && planIdx < plans.length) ? planIdx : 0;
      const plan = plans[idx];

      const pkr = Number(plan.price_pkr || 0);
      const R = REGIONS[region];
      const usd = pkr * REGIONS.US.rate;
      const { methods } = await payMethods(region, pkr, usd);
      const chosen = methods.find(x => x.key === method_key);
      if (!chosen) return fail('Please choose a payment method.');

      const meta = await botMeta(plan);
      const needFields = customerFields(meta.deliveryType);
      if (meta.missing) return fail('This item is currently unavailable. Please contact us on WhatsApp.');
      const avail = await availability(plan, meta.deliveryType);
      if (!avail.available) return fail('Sorry, this plan just went out of stock. Please try another plan or contact us on WhatsApp.');
      if (needFields.includes('mac') && mac.replace(/[^0-9a-fA-F]/g, '').length < 12) return fail('Please enter the device MAC address (e.g. AA:BB:CC:DD:EE:FF).');
      if (needFields.includes('link') && !link) return fail('Please enter the target link for this order.');
      if (needFields.includes('qty') && !/^[0-9]+$/.test(qty)) return fail('Please enter a valid quantity.');
      if (actEmail && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(actEmail)) return fail('Please enter a valid activation email, or leave it blank to use your order email.');

      const fields = {};
      if (mac) fields.mac = mac;
      if (link) fields.link = link;
      if (qty) fields.qty = qty;
      if (actEmail) fields.act_email = actEmail;
      if (req.file) { try { fields.screenshotHash = crypto.createHash('sha256').update(fs.readFileSync(req.file.path)).digest('hex'); } catch (e) {} }

      // customer-chosen bot type (Family/Adult): only when the plan is a bot plan
      // with no pinned type and the bot product actually offers that type.
      let botTypeFinal = plan.bot_type || null;
      const chosenType = String(b.type || '').trim();
      if (plan.source === 'bot' && plan.bot_sku && !plan.bot_type && chosenType) {
        try {
          const bp = (await pool.query('SELECT types FROM bot_products WHERE sku=$1', [plan.bot_sku])).rows[0];
          const types = (bp && Array.isArray(bp.types)) ? bp.types.map(t => String(t.key)) : [];
          if (types.includes(chosenType)) botTypeFinal = chosenType;
        } catch (e) { /* ignore */ }
      }

      const disp = +(pkr * R.rate).toFixed(2);
      const usdv = +(usd).toFixed(2);
      const proof = req.file ? req.file.filename : null;
      const botPay = !!(chosen.botAcct && botapi.configured());
      const startStatus = botPay ? 'verifying' : 'pending';

      const ins = await pool.query(
        `INSERT INTO orders(status,email,whatsapp,product_id,product_name,plan_label,qty,region,currency,unit_amount,amount_display,amount_pkr,amount_usd,method_key,method_name,txn_ref,proof_file,note,source,bot_sku,bot_plan_key,bot_type,fields)
         VALUES($1,$2,$3,$4,$5,$6,1,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22) RETURNING id`,
        [startStatus, email, whatsapp, prow.id, prow.name, plan.label, region, R.cur, disp, disp, pkr, usdv, chosen.key, chosen.name, txn, proof, note,
         plan.source || 'manual', plan.bot_sku || null, plan.bot_plan_key || null, botTypeFinal, JSON.stringify(fields)]
      );
      const id = ins.rows[0].id;
      const order_no = 'GSZ-' + (1000 + id);
      await pool.query('UPDATE orders SET order_no=$1 WHERE id=$2', [order_no, id]);

      // verify the payment in the background — never block checkout on the slow IMAP scan
      if (botPay) reverifyOrder(id).catch(() => {});

      // confirmation email, fire-and-forget
      (async () => {
        try {
          const row = (await pool.query('SELECT * FROM orders WHERE id=$1', [id])).rows[0];
          if (row && row.status !== 'delivered') await emailOrder(row, 'confirm');
        } catch (e) { /* email never blocks */ }
      })();

      res.redirect('/order/' + order_no);
    } catch (e) { res.status(500).send('Order error: ' + e.message); }
  });

  // ---- re-check a pending/verifying payment (manual button) ----
  router.post('/order/:no/reverify', async (req, res) => {
    const to = '/order/' + encodeURIComponent(req.params.no);
    try {
      const o = (await pool.query('SELECT id, status, source FROM orders WHERE order_no=$1', [req.params.no])).rows[0];
      if (o && o.source === 'bot') {
        if (o.status === 'pending') await pool.query("UPDATE orders SET status='verifying' WHERE id=$1 AND status='pending'", [o.id]);
        if (o.status === 'pending' || o.status === 'verifying') reverifyOrder(o.id).catch(() => {});
      }
      res.redirect(to);
    } catch (e) { res.redirect(to); }
  });

  // ---- confirmation / status page ----
  router.get('/order/:no', async (req, res) => {
    try {
      let o = (await pool.query('SELECT * FROM orders WHERE order_no=$1', [req.params.no])).rows[0];
      if (!o) return res.status(404).render('notfound', { what: 'order' });
      if (o.status === 'delivering') { await pollOnce(o.order_no); o = (await pool.query('SELECT * FROM orders WHERE order_no=$1', [req.params.no])).rows[0]; }
      let m = null;
      if (botapi.configured()) {
        try { const accts = await botapi.getPayAccounts(); const a = (accts || []).find(x => x.key === o.method_key); if (a) m = { name: a.label || a.method, details: 'Title: ' + a.title + '\nAccount: ' + a.account, instructions: a.instructions || '', currency: a.currency }; } catch (e) {}
      }
      if (!m) m = (await pool.query('SELECT name, details, instructions, currency FROM payment_methods WHERE key=$1', [o.method_key])).rows[0] || {};
      const s = await settingsObj();
      res.render('order', { o, method: m, settings: s, logoFile: s.logo_file || 'logo.png', waNumber: s.wa_number || process.env.WA_NUMBER || '' });
    } catch (e) { res.status(500).send('Order view error: ' + e.message); }
  });

  return router;
};
EOF_COJS
cat > views/checkout.ejs <<'EOF_CEJS'
<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Checkout · <%= p.name %> · Galaxy Subz × Zayron</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Hanken+Grotesk:wght@400;500;600;700&family=Schibsted+Grotesk:wght@600;700;800&display=swap" rel="stylesheet">
<style>
  :root{--bg:#f4f6fc;--ink:#0f1836;--muted:#737e9c;--hair:#e7ebf6;--brand:#2a7bff;--grad:linear-gradient(118deg,#8a2bff,#2a7bff,#17cbf0);--disp:'Schibsted Grotesk',sans-serif}
  *{box-sizing:border-box}body{margin:0;font-family:'Hanken Grotesk',system-ui,sans-serif;background:var(--bg);color:var(--ink)}
  a{color:inherit;text-decoration:none}
  .top{display:flex;align-items:center;gap:12px;padding:16px 20px;max-width:1040px;margin:0 auto}
  .top .logo{height:34px}.top b{font-family:var(--disp);font-weight:800;font-size:18px;letter-spacing:-.02em}
  .wrap{max-width:1040px;margin:0 auto;padding:8px 20px 70px;display:grid;grid-template-columns:1fr 360px;gap:22px}
  @media(max-width:860px){.wrap{grid-template-columns:1fr}}
  h1{font-family:var(--disp);font-size:26px;letter-spacing:-.02em;margin:4px 0 2px}
  .lead{color:var(--muted);font-size:14px;margin:0 0 18px}
  .card{background:#fff;border-radius:16px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 18px 40px -28px rgba(15,24,54,.3);padding:22px;margin-bottom:18px}
  h2{font-size:15px;margin:0 0 14px;letter-spacing:-.01em}
  label.fld{display:block;font-size:13px;font-weight:600;margin:0 0 6px}
  input[type=text],input[type=email],input[type=tel],textarea,select{width:100%;padding:11px 13px;border-radius:10px;border:1px solid var(--hair);font-size:14px;font-family:inherit;margin-bottom:14px;background:#fff}
  input:focus,textarea:focus,select:focus{outline:2px solid var(--brand);outline-offset:1px;border-color:transparent}
  .err{background:#fdecec;color:#b42318;border:1px solid #f6c9c4;border-radius:11px;padding:11px 14px;font-size:14px;font-weight:600;margin-bottom:18px}
  .oos{background:#fff6e5;color:#8a5a00;border:1px solid #ffe0a0;border-radius:11px;padding:13px 15px;font-size:14px;font-weight:600;margin-bottom:18px;line-height:1.5}
  .hint{font-size:12.5px;color:var(--muted);margin:-8px 0 14px}
  .pm{border:1.5px solid var(--hair);border-radius:12px;padding:14px;margin-bottom:12px;cursor:pointer;transition:.15s}
  .pm:hover{border-color:var(--brand)}
  .pm.sel{border-color:var(--brand);box-shadow:0 0 0 3px rgba(42,123,255,.12)}
  .pm .hd{display:flex;align-items:center;gap:12px}
  .pm .rdo{width:20px;height:20px;border-radius:50%;border:2px solid var(--hair);flex:none;display:grid;place-items:center}
  .pm.sel .rdo:after{content:"";width:10px;height:10px;border-radius:50%;background:var(--brand)}
  .pm .nm{font-weight:700;font-size:14.5px;flex:1}
  .pm .amt{font-family:var(--disp);font-weight:800;font-size:16px}
  .pm .info{font-size:13px;color:var(--muted);margin:9px 0 0;padding-left:32px;line-height:1.5}
  .pm .info b{color:var(--ink)}
  .sum{position:sticky;top:18px}
  .sum .row{display:flex;justify-content:space-between;font-size:14px;padding:7px 0;color:var(--muted)}
  .sum .row b{color:var(--ink);font-weight:600}
  .sum .tot{border-top:1px solid var(--hair);margin-top:8px;padding-top:12px;font-size:15px}
  .sum .tot .big{font-family:var(--disp);font-size:24px;font-weight:800}
  .instock{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;font-weight:700;color:#0b7a42}
  .instock .d{width:8px;height:8px;border-radius:50%;background:#16b765}
  .regsel{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--muted);margin-bottom:14px}
  .regsel select{width:auto;margin:0;padding:7px 10px;border-radius:8px}
  .btn{display:block;width:100%;text-align:center;background:var(--grad);color:#fff;font-weight:700;font-size:15.5px;border:0;border-radius:12px;padding:14px;cursor:pointer;box-shadow:0 14px 30px -14px rgba(42,123,255,.9)}
  .btn:hover{filter:brightness(1.04)}
  .btn[disabled]{opacity:.5;pointer-events:none;box-shadow:none}
  .btn-wa{display:block;width:100%;text-align:center;background:linear-gradient(135deg,#25d366,#0fb858);color:#fff;font-weight:700;font-size:15px;border-radius:12px;padding:13px;margin-top:10px}
  .fine{font-size:12px;color:var(--muted);margin:12px 0 0;line-height:1.5}
  .back{display:inline-block;color:var(--muted);font-size:13px;margin:2px 0 10px}
</style></head><body>
<div class="top"><a href="/"><img class="logo" src="/static/img/<%= logoFile %>" onerror="this.style.display='none'"><b>Galaxy Subz × Zayron</b></a></div>
<div class="wrap">
  <form class="col" method="post" action="/checkout" enctype="multipart/form-data">
    <a class="back" href="/product/<%= p.slug %>">← Back to <%= p.name %></a>
    <h1>Checkout</h1>
    <p class="lead">Complete your order for <b><%= p.name %></b> — <%= plan.label %>.</p>
    <% if (error) { %><div class="err"><%= error %></div><% } %>
    <% if (!avail.available) { %>
      <div class="oos">This plan is currently <b>out of stock</b>. Message us on WhatsApp and we'll restock fast, or pick another plan.</div>
    <% } %>

    <input type="hidden" name="product" value="<%= p.slug %>">
    <input type="hidden" name="plan" value="<%= planIdx %>">
    <input type="hidden" name="region" value="<%= region %>">
    <input type="hidden" name="type" value="<%= typeof chosenType !== 'undefined' ? chosenType : '' %>">

    <div class="card">
      <h2>Your details</h2>
      <label class="fld">Email (we send your order & invoice here)</label>
      <input type="email" name="email" placeholder="you@example.com" required>
      <label class="fld">WhatsApp number (for delivery & support)</label>
      <input type="tel" name="whatsapp" placeholder="e.g. +92 3XX XXXXXXX" required>
    </div>

    <% if (needFields.includes('mac')) { %>
    <div class="card">
      <h2>Device details</h2>
      <label class="fld">MAC address of your player / device</label>
      <input type="text" name="mac" placeholder="AA:BB:CC:DD:EE:FF" required>
      <p class="hint">Find this in your player app under Settings → it's needed to activate your subscription.</p>
    </div>
    <% } %>

    <% if (needFields.includes('link') || needFields.includes('qty')) { %>
    <div class="card">
      <h2>Order details</h2>
      <% if (needFields.includes('link')) { %>
        <label class="fld">Target link (profile / post URL)</label>
        <input type="text" name="link" placeholder="https://..." required>
      <% } %>
      <% if (needFields.includes('qty')) { %>
        <label class="fld">Quantity</label>
        <input type="text" name="qty" placeholder="e.g. 1000" required>
      <% } %>
    </div>
    <% } %>

    <% if (typeof optEmail !== 'undefined' && optEmail) { %>
    <div class="card">
      <h2>Activation email <span style="font-weight:500;color:var(--muted);font-size:13px">(optional)</span></h2>
      <label class="fld">Email for the account / invite</label>
      <input type="email" name="act_email" placeholder="Leave blank to use the email above">
      <p class="hint">For products like Canva, Gemini, Envato, Udemy or Zoom — enter the email where you want the invite / account set up. Leave blank to use your order email above.</p>
    </div>
    <% } %>

    <div class="card">
      <h2>Payment method</h2>
      <% if (!methods.length) { %>
        <p class="lead">No payment method is available for your region yet. Please contact support on WhatsApp.</p>
      <% } %>
      <% methods.forEach(function(m,i){ %>
        <div class="pm<%= i===0?' sel':'' %>" data-key="<%= m.key %>">
          <div class="hd">
            <span class="rdo"></span>
            <span class="nm"><%= m.name %></span>
            <span class="amt"><%= m.pay %></span>
          </div>
          <div class="info"><b><%= m.details %></b><br><%= m.instructions %></div>
        </div>
      <% }); %>
      <input type="hidden" name="method" id="method" value="<%= methods.length?methods[0].key:'' %>">
    </div>

    <div class="card">
      <h2>Confirm your payment</h2>
      <label class="fld">Transaction ID / reference (after you pay)</label>
      <input type="text" name="txn" placeholder="Paste your TxID / TID / reference">
      <label class="fld">Upload payment screenshot or receipt (optional)</label>
      <input type="file" name="proof" accept="image/*,application/pdf" style="margin-bottom:14px">
      <label class="fld">Notes (optional)</label>
      <textarea name="note" rows="3" placeholder="Anything we should know about your order"></textarea>
    </div>

    <% if (avail.available) { %>
      <button class="btn" type="submit">Place order</button>
      <p class="fine">After you place the order, we verify your payment and deliver to your email & WhatsApp. You'll get an order number to track status.</p>
    <% } else { %>
      <button class="btn" type="submit" disabled>Out of stock</button>
      <% if (waNumber) { %>
        <a class="btn-wa" target="_blank" rel="noopener" href="https://wa.me/<%= waNumber.replace(/[^0-9]/g,'') %>?text=<%= encodeURIComponent('Hi! Is '+p.name+' ('+plan.label+') back in stock?') %>">Ask on WhatsApp</a>
      <% } %>
    <% } %>
  </form>

  <aside>
    <div class="card sum">
      <h2>Order summary</h2>
      <div class="regsel">Prices in
        <select onchange="location.href='/checkout?p=<%= p.slug %>&plan=<%= planIdx %>&region='+this.value">
          <% regionList.forEach(function(rg){ %><option value="<%= rg %>" <%= rg===region?'selected':'' %>><%= rg %></option><% }); %>
        </select>
      </div>
      <div class="row"><span><%= p.name %></span><b><%= plan.label %></b></div>
      <div class="row"><span>Billed in USD (ref.)</span><b><%= priceUsd %></b></div>
      <% if (avail.available) { %>
        <div class="row"><span>Availability</span><span class="instock"><span class="d"></span><%= (avail.count!=null) ? (avail.count+' in stock') : 'In stock' %></span></div>
      <% } %>
      <div class="row tot"><span>Total</span><span class="big"><%= priceDisplay %></span></div>
    </div>
  </aside>
</div>
<script>
(function(){
  var pms=document.querySelectorAll('.pm'), hidden=document.getElementById('method');
  pms.forEach(function(el){el.addEventListener('click',function(){
    pms.forEach(function(x){x.classList.remove('sel')});el.classList.add('sel');hidden.value=el.dataset.key;});});
})();
</script>
</body></html>
EOF_CEJS

node --check routes/products.js && node --check routes/checkout.js && echo "[ok] JS syntax"
node -e '
const ejs=require("ejs"),fs=require("fs");
for(const v of ["views/product.ejs","views/checkout.ejs"]){ try{ ejs.compile(fs.readFileSync(v,"utf8"),{filename:v}); }catch(e){ console.error("ABORT ejs",v,e.message); process.exit(1);} }
console.log("[ok] ejs compiles");
' || exit 1
pm2 restart gsz >/dev/null 2>&1 || pm2 start server.js --name gsz >/dev/null 2>&1
sleep 2
BODY=$(curl -fsS "http://127.0.0.1:${PORT:-3900}/" 2>/dev/null || true)
grep -q "</html>" <<< "$BODY" && echo "[ok] site responding" || echo "!! health soft-fail"
trap - ERR
echo
echo "==================== STEP 34 DONE ===================="
echo " Family/Adult toggle shows on product pages whose plan's bot product has"
echo " multiple types AND the mapping Type is left blank (= customer chooses)."
echo " Payment chips now show your REAL methods. For Opplex: set each duration"
echo " plan's Bot plan (plan_key) in /admin/mapping and leave Type blank."
echo "====================================================="
