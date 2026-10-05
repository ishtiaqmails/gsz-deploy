#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 15: payments admin + pages + invoice
#  RUN: cd /opt/gsz-deploy && git pull && bash step15.sh
#  Adds (all self-contained, no new npm deps):
#   1. Admin → Payments: edit the real Binance/bank/JazzCash/Easypaisa/
#      TapTap receiving details shown at checkout (new sidebar link).
#   2. /about and /resellers pages (wires the existing header + footer
#      links that were "coming soon").
#   3. Printable invoice at /order/<no>/invoice (browser Save-as-PDF),
#      linked from the order confirmation page.
#  New files: routes/adminPayments.js, routes/pages.js, routes/invoice.js,
#             views/admin/payments.ejs, views/about.ejs, views/resellers.ejs,
#             views/invoice.ejs
#  Patches:   views/admin/_shell_top.ejs, views/partials/store_top.ejs,
#             views/partials/store_bottom.ejs, views/order.ejs, server.js
#  Asset version -> v=15. Auto-rollback on health-check failure.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views" ] || { echo "ABORT: $APP/views not found"; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"; : "${DB_USER:?}"; : "${DB_NAME:?}"; : "${DB_PASS:?}"
echo "== Galaxy Subz x Zayron — Step 15 (payments admin + pages + invoice) · port $PORT =="
ts=$(date +%s)
PSQL(){ PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" "$@"; }

# --- backups of files we PATCH ---
cp -a "$APP/views/admin/_shell_top.ejs"      "$APP/views/admin/_shell_top.ejs.bak-step15.$ts"
cp -a "$APP/views/partials/store_top.ejs"    "$APP/views/partials/store_top.ejs.bak-step15.$ts"
cp -a "$APP/views/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs.bak-step15.$ts"
cp -a "$APP/views/order.ejs"                 "$APP/views/order.ejs.bak-step15.$ts"
cp -a "$APP/server.js"                        "$APP/server.js.bak-step15.$ts"

restore(){
  echo ">> rolling back Step 15"
  cp -a "$APP/views/admin/_shell_top.ejs.bak-step15.$ts"      "$APP/views/admin/_shell_top.ejs"
  cp -a "$APP/views/partials/store_top.ejs.bak-step15.$ts"    "$APP/views/partials/store_top.ejs"
  cp -a "$APP/views/partials/store_bottom.ejs.bak-step15.$ts" "$APP/views/partials/store_bottom.ejs"
  cp -a "$APP/views/order.ejs.bak-step15.$ts"                 "$APP/views/order.ejs"
  cp -a "$APP/server.js.bak-step15.$ts"                        "$APP/server.js"
  rm -f "$APP/routes/adminPayments.js" "$APP/routes/pages.js" "$APP/routes/invoice.js" \
        "$APP/views/admin/payments.ejs" "$APP/views/about.ejs" "$APP/views/resellers.ejs" "$APP/views/invoice.ejs"
  pm2 restart gsz >/dev/null 2>&1 || true
}
cat > "$APP/routes/adminPayments.js" <<'GSZ_AP_JS'
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();

  function auth(req, res, next) {
    if (req.session && req.session.admin) return next();
    return res.redirect('/admin/login');
  }

  // --- list / edit form ---
  router.get('/payments', auth, async (req, res) => {
    try {
      const rows = (await pool.query(
        'SELECT id, key, name, currency, scope, details, instructions, active, sort FROM payment_methods ORDER BY sort, id'
      )).rows;
      res.render('admin/payments', { rows, flash: req.query.ok || null, active: 'payments', title: 'Payments' });
    } catch (e) { res.status(500).send('Payments error: ' + e.message); }
  });

  // --- save all methods ---
  router.post('/payments', auth, express.urlencoded({ extended: true, limit: '1mb' }), async (req, res) => {
    const m = (req.body && req.body.m) || {};
    const SCOPES = ['all', 'pk', 'global'];
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      for (const id of Object.keys(m)) {
        const pid = parseInt(id, 10);
        if (!Number.isFinite(pid)) continue;
        const r = m[id] || {};
        const name = String(r.name || '').trim();
        if (!name) continue;
        const currency = (String(r.currency || 'USD').trim().toUpperCase().slice(0, 8)) || 'USD';
        const scope = SCOPES.includes(String(r.scope || '')) ? r.scope : 'all';
        const details = String(r.details || '').trim();
        const instructions = String(r.instructions || '').trim();
        const activeOn = (r.active === 'on' || r.active === 'true' || r.active === true);
        const sortNum = parseInt(r.sort, 10);
        const sortv = Number.isFinite(sortNum) ? sortNum : 0;
        await client.query(
          'UPDATE payment_methods SET name=$1, currency=$2, scope=$3, details=$4, instructions=$5, active=$6, sort=$7 WHERE id=$8',
          [name, currency, scope, details, instructions, activeOn, sortv, pid]
        );
      }
      await client.query('COMMIT');
      res.redirect('/admin/payments?ok=' + encodeURIComponent('Payment details saved'));
    } catch (e) {
      try { await client.query('ROLLBACK'); } catch (x) {}
      res.status(500).send('Payments save error: ' + e.message);
    } finally { client.release(); }
  });

  return router;
};

GSZ_AP_JS

cat > "$APP/routes/pages.js" <<'GSZ_PAGES_JS'
const express = require('express');
const storefront = require('../lib/storefront');

module.exports = function (pool) {
  const router = express.Router();

  async function shell() {
    const cats = await storefront.loadCats(pool);
    const products = await storefront.loadProducts(pool);
    const settings = await storefront.loadSettings(pool);
    const waNumber = settings.wa_number || process.env.WA_NUMBER || '';
    return {
      cats, settings, waNumber,
      logoFile: settings.logo_file || 'logo.png',
      siteName: settings.site_name || 'Galaxy Subz × Zayron',
      shellJson: storefront.shellJson(cats, products, settings, waNumber)
    };
  }

  router.get('/about', async (req, res) => {
    try {
      const s = await shell();
      res.render('about', Object.assign({ title: 'About · ' + s.siteName }, s));
    } catch (e) { res.status(500).send('About error: ' + e.message); }
  });

  router.get('/resellers', async (req, res) => {
    try {
      const s = await shell();
      res.render('resellers', Object.assign({ title: 'Reseller panels · ' + s.siteName }, s));
    } catch (e) { res.status(500).send('Resellers error: ' + e.message); }
  });

  return router;
};

GSZ_PAGES_JS

cat > "$APP/routes/invoice.js" <<'GSZ_INV_JS'
const express = require('express');
const storefront = require('../lib/storefront');

module.exports = function (pool) {
  const router = express.Router();

  router.get('/order/:no/invoice', async (req, res) => {
    try {
      const o = (await pool.query('SELECT * FROM orders WHERE order_no=$1', [req.params.no])).rows[0];
      if (!o) return res.status(404).render('notfound', { what: 'order' });
      const settings = await storefront.loadSettings(pool);
      res.render('invoice', {
        o, settings,
        logoFile: settings.logo_file || 'logo.png',
        siteName: settings.site_name || 'Galaxy Subz × Zayron',
        waNumber: settings.wa_number || process.env.WA_NUMBER || ''
      });
    } catch (e) { res.status(500).send('Invoice error: ' + e.message); }
  });

  return router;
};

GSZ_INV_JS

cat > "$APP/views/admin/payments.ejs" <<'GSZ_PAY_EJS'
<%- include('_shell_top', { active:'payments', title:'Payments' }) %>
<p class="sub" style="margin-bottom:16px">Set the real receiving details customers see at checkout. Whatever you put in <b>Receiving details</b> is shown on the payment step and on the order page. Turn a method off to hide it.</p>
<% if (flash) { %><div class="flash"><%= flash %></div><% } %>

<form method="post" action="/admin/payments">
  <% rows.forEach(function(m){ %>
  <div class="card">
    <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:14px">
      <h2 style="margin:0"><%= m.name %> <span style="color:var(--muted);font-weight:600;font-size:12.5px">· <%= m.key %></span></h2>
      <label style="display:flex;align-items:center;gap:7px;font-size:13px;font-weight:700;white-space:nowrap;margin:0">
        <input type="checkbox" name="m[<%= m.id %>][active]" <%= m.active ? 'checked' : '' %> style="width:auto;margin:0"> Show at checkout
      </label>
    </div>

    <div style="display:grid;grid-template-columns:1fr 110px 170px;gap:14px">
      <div><label class="fld">Display name</label><input type="text" name="m[<%= m.id %>][name]" value="<%= m.name %>"></div>
      <div><label class="fld">Currency</label><input type="text" name="m[<%= m.id %>][currency]" value="<%= m.currency %>"></div>
      <div><label class="fld">Show to region</label>
        <select name="m[<%= m.id %>][scope]">
          <option value="all"    <%= m.scope==='all'    ? 'selected' : '' %>>All regions</option>
          <option value="pk"     <%= m.scope==='pk'     ? 'selected' : '' %>>Pakistan only</option>
          <option value="global" <%= m.scope==='global' ? 'selected' : '' %>>Global (outside PK)</option>
        </select>
      </div>
    </div>

    <label class="fld">Receiving details (shown to customer)</label>
    <textarea name="m[<%= m.id %>][details]" rows="3" placeholder="e.g. Account title: Muhammad Ishtiaq&#10;Account no: 0000-0000000000&#10;IBAN: PK00XXXX0000000000000000"><%= m.details %></textarea>

    <label class="fld">Instructions (optional)</label>
    <textarea name="m[<%= m.id %>][instructions]" rows="2"><%= m.instructions %></textarea>

    <input type="hidden" name="m[<%= m.id %>][sort]" value="<%= m.sort %>">
  </div>
  <% }); %>

  <div style="position:sticky;bottom:0;padding:14px 0;background:linear-gradient(0deg,var(--bg) 55%,transparent)">
    <button class="btn btn-p" type="submit">Save payment details</button>
    <span class="sub" style="margin-left:12px">Changes go live on checkout immediately.</span>
  </div>
</form>

<%- include('_shell_bottom') %>

GSZ_PAY_EJS

cat > "$APP/views/about.ejs" <<'GSZ_ABOUT_EJS'
<%- include('partials/store_top') %>

<section class="section">
  <div class="wrap" style="max-width:860px">
    <span class="eyebrow"><span class="dot"></span>About us</span>
    <h1 style="font-family:var(--display);font-weight:800;font-size:clamp(30px,5vw,50px);letter-spacing:-.025em;line-height:1.04;margin:10px 0 18px">
      Premium digital subscriptions, delivered the way they should be.
    </h1>
    <p style="font-size:17px;line-height:1.7;color:var(--ink-soft);max-width:60ch">
      Galaxy&nbsp;Subz&nbsp;× Zayron is a home for premium streaming, IPTV, creative tools, VPNs and
      player activations — sold at fair prices and delivered fast, with real people on WhatsApp when you need them.
      We've been serving customers and resellers since <%= settings.since || '2021' %>.
    </p>
  </div>
</section>

<section class="section tint">
  <div class="wrap">
    <div class="sec-head"><div><span class="eyebrow"><span class="dot"></span>What we stand for</span><h2>Built on trust and speed</h2></div></div>
    <div class="pgrid" style="grid-template-columns:repeat(auto-fill,minmax(240px,1fr))">
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Fast delivery</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Most orders are delivered within minutes, any time of day — no waiting around for business hours.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Fair pricing</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Honest prices in your own currency, with reseller rates for people buying in volume.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Real support</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">A real person on WhatsApp for setup, renewals and anything that doesn't go to plan.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">One trusted family</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Backed by our wider family of brands across subscriptions, IPTV and our own Zayron player.</p>
      </div>
    </div>
  </div>
</section>

<section class="section">
  <div class="wrap" style="text-align:center">
    <h2 style="font-family:var(--display);font-weight:800;font-size:clamp(24px,3vw,34px);letter-spacing:-.02em;margin:0 0 10px">Questions before you buy?</h2>
    <p style="color:var(--muted);margin:0 0 22px">Message us on WhatsApp — we usually reply within minutes.</p>
    <a class="btn btn-wa btn-lg" href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')) : '#' %>" target="_blank" rel="noopener">
      <svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>Chat on WhatsApp
    </a>
  </div>
</section>

<%- include('partials/store_bottom') %>

GSZ_ABOUT_EJS

cat > "$APP/views/resellers.ejs" <<'GSZ_RES_EJS'
<%- include('partials/store_top') %>

<section class="section">
  <div class="wrap" style="max-width:860px">
    <span class="eyebrow"><span class="dot"></span>For resellers</span>
    <h1 style="font-family:var(--display);font-weight:800;font-size:clamp(30px,5vw,50px);letter-spacing:-.025em;line-height:1.04;margin:10px 0 18px">
      Sell premium subscriptions &amp; IPTV — with stock, prices and delivery already sorted.
    </h1>
    <p style="font-size:17px;line-height:1.7;color:var(--ink-soft);max-width:60ch">
      Run your own subscription business without the hassle. Get reseller pricing, instant delivery and a steady
      supply of the products your customers already want — IPTV, streaming, tools, VPNs and player activations.
    </p>
    <div style="margin-top:26px;display:flex;gap:12px;flex-wrap:wrap">
      <a class="btn btn-primary btn-lg" href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')+'?text='+encodeURIComponent('Hi! I want to become a reseller.')) : '#' %>" target="_blank" rel="noopener">Become a reseller</a>
      <a class="btn btn-ghost btn-lg" href="/">Browse the store</a>
    </div>
  </div>
</section>

<section class="section tint">
  <div class="wrap">
    <div class="sec-head"><div><span class="eyebrow"><span class="dot"></span>Why resell with us</span><h2>Everything you need to start today</h2></div></div>
    <div class="pgrid" style="grid-template-columns:repeat(auto-fill,minmax(240px,1fr))">
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Reseller pricing</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Lower rates that leave you a healthy margin, with better pricing as your volume grows.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Instant delivery</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Orders are fulfilled automatically through our system, so your customers never wait.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Wide catalog</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">One source for IPTV, streaming accounts, premium tools, VPNs and player activations.</p>
      </div>
      <div class="pcard" style="padding:22px">
        <h3 style="font-family:var(--display);font-weight:800;font-size:18px;margin:0 0 8px">Support that has your back</h3>
        <p style="color:var(--ink-soft);font-size:14.5px;line-height:1.6;margin:0">Renewals, replacements and setup help on WhatsApp whenever you need it.</p>
      </div>
    </div>
  </div>
</section>

<section class="section">
  <div class="wrap" style="text-align:center">
    <h2 style="font-family:var(--display);font-weight:800;font-size:clamp(24px,3vw,34px);letter-spacing:-.02em;margin:0 0 10px">Ready to start reselling?</h2>
    <p style="color:var(--muted);margin:0 0 22px">Message us on WhatsApp and we'll get you set up with pricing and access.</p>
    <a class="btn btn-wa btn-lg" href="<%= waNumber ? ('https://wa.me/'+waNumber.replace(/[^0-9]/g,'')+'?text='+encodeURIComponent('Hi! I want to become a reseller.')) : '#' %>" target="_blank" rel="noopener">
      <svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>Become a reseller
    </a>
  </div>
</section>

<%- include('partials/store_bottom') %>

GSZ_RES_EJS

cat > "$APP/views/invoice.ejs" <<'GSZ_INV_EJS'
<!doctype html><html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Invoice <%= o.order_no %> · <%= siteName %></title>
<style>
  :root{--ink:#0e1430;--muted:#6b7391;--line:#e7ebf6;--brand:#2a6cff;--grad:linear-gradient(118deg,#8a2bff,#2a7bff);--wash:#f7f9fe}
  *{box-sizing:border-box}
  body{margin:0;background:#eef1f8;color:var(--ink);font-family:'Hanken Grotesk',system-ui,'Segoe UI',sans-serif;font-size:14px;line-height:1.5}
  .sheet{max-width:820px;margin:28px auto;background:#fff;border-radius:14px;box-shadow:0 20px 60px -30px rgba(14,20,48,.4);padding:clamp(24px,5vw,54px)}
  .top{display:flex;justify-content:space-between;align-items:flex-start;gap:20px;flex-wrap:wrap}
  .brand{display:flex;align-items:center;gap:11px}
  .brand img{height:42px;width:auto}
  .brand b{font-family:'Bricolage Grotesque',system-ui,sans-serif;font-weight:800;font-size:19px;letter-spacing:-.02em;line-height:1.1}
  .brand .dim{display:block;font-size:12px;color:var(--muted);font-weight:600}
  .doc{text-align:right}
  .doc h1{font-family:'Bricolage Grotesque',system-ui,sans-serif;font-size:30px;letter-spacing:.06em;margin:0;color:var(--brand)}
  .doc .meta{color:var(--muted);font-size:13px;margin-top:6px}
  .doc .meta b{color:var(--ink)}
  .parties{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin:30px 0 8px}
  .parties h4{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);margin:0 0 7px}
  .parties p{margin:0;line-height:1.6}
  table{width:100%;border-collapse:collapse;margin-top:26px}
  th{text-align:left;font-size:11px;letter-spacing:.05em;text-transform:uppercase;color:var(--muted);padding:10px 0;border-bottom:2px solid var(--line)}
  td{padding:14px 0;border-bottom:1px solid var(--line);vertical-align:top}
  .r{text-align:right}
  .totals{margin-top:18px;margin-left:auto;width:min(320px,100%)}
  .totals .row{display:flex;justify-content:space-between;padding:7px 0;color:var(--muted)}
  .totals .row b{color:var(--ink)}
  .totals .grand{border-top:2px solid var(--line);margin-top:6px;padding-top:12px;font-size:19px}
  .totals .grand b{font-family:'Bricolage Grotesque',system-ui,sans-serif;font-weight:800}
  .pill{display:inline-block;font-size:11px;font-weight:800;letter-spacing:.03em;text-transform:uppercase;padding:4px 10px;border-radius:999px}
  .note{margin-top:34px;padding-top:18px;border-top:1px solid var(--line);color:var(--muted);font-size:12.5px;line-height:1.6}
  .bar{max-width:820px;margin:0 auto 28px;display:flex;gap:10px;justify-content:flex-end}
  .btn{border:0;cursor:pointer;font-family:inherit;font-weight:700;font-size:13.5px;border-radius:10px;padding:11px 18px}
  .btn-p{background:var(--grad);color:#fff}
  .btn-g{background:#fff;color:var(--ink);box-shadow:inset 0 0 0 1px var(--line)}
  @media print{
    body{background:#fff}
    .bar{display:none}
    .sheet{box-shadow:none;margin:0;max-width:none;border-radius:0;padding:0}
  }
</style></head><body>
<%
  var isRs = (o.currency === 'Rs');
  function money(v){ return isRs ? ('Rs '+Math.round(Number(v||0)).toLocaleString('en-US')) : (o.currency+' '+Number(v||0)); }
  var statusColor = {pending:'#9a6700',paid:'#1b6fd6',approved:'#0b7a42',delivered:'#0b7a42',rejected:'#b42318',cancelled:'#737e9c'}[o.status] || '#737e9c';
  var statusBg = {pending:'#fff6e5',paid:'#e7f1ff',approved:'#e9fbf1',delivered:'#e9fbf1',rejected:'#fdeceb',cancelled:'#eef1f8'}[o.status] || '#eef1f8';
%>
<div class="bar">
  <button class="btn btn-g" onclick="window.location='/order/<%= o.order_no %>'">← Order</button>
  <button class="btn btn-p" onclick="window.print()">Download / print</button>
</div>

<div class="sheet">
  <div class="top">
    <div class="brand">
      <img src="/static/img/<%= logoFile %>" alt="" onerror="this.style.display='none'">
      <b><%= siteName %><span class="dim">Premium subscriptions &amp; IPTV</span></b>
    </div>
    <div class="doc">
      <h1>INVOICE</h1>
      <div class="meta">No. <b><%= o.order_no %></b></div>
      <div class="meta"><%= new Date(o.created_at).toLocaleDateString('en-GB', {day:'2-digit',month:'short',year:'numeric'}) %></div>
      <div class="meta" style="margin-top:8px"><span class="pill" style="color:<%= statusColor %>;background:<%= statusBg %>"><%= o.status %></span></div>
    </div>
  </div>

  <div class="parties">
    <div>
      <h4>From</h4>
      <p><b><%= siteName %></b><br>
      <% if (waNumber) { %>WhatsApp: <%= waNumber %><br><% } %>
      <% if (settings.site_domain) { %><%= settings.site_domain %><% } %></p>
    </div>
    <div>
      <h4>Billed to</h4>
      <p><% if (o.email) { %><b><%= o.email %></b><br><% } %>
      <% if (o.whatsapp) { %><%= o.whatsapp %><br><% } %>
      <% if (o.region) { %>Region: <%= o.region %><% } %></p>
    </div>
  </div>

  <table>
    <thead><tr><th>Description</th><th class="r">Qty</th><th class="r">Amount</th></tr></thead>
    <tbody>
      <tr>
        <td><b><%= o.product_name %></b><% if (o.plan_label) { %><br><span style="color:var(--muted)"><%= o.plan_label %></span><% } %></td>
        <td class="r"><%= o.qty || 1 %></td>
        <td class="r"><%= money(o.amount_display) %></td>
      </tr>
    </tbody>
  </table>

  <div class="totals">
    <div class="row"><span>Subtotal</span><b><%= money(o.amount_display) %></b></div>
    <div class="row grand"><span>Total</span><b><%= money(o.amount_display) %></b></div>
  </div>

  <div class="parties" style="margin-top:30px">
    <div>
      <h4>Payment method</h4>
      <p><b><%= o.method_name || '—' %></b><% if (o.txn_ref) { %><br><span style="color:var(--muted)">Ref: <%= o.txn_ref %></span><% } %></p>
    </div>
  </div>

  <div class="note">
    This invoice was generated for order <%= o.order_no %>. Digital goods are delivered to your email and WhatsApp after
    payment is verified. For any help with this order, contact us on WhatsApp<%= waNumber ? (' at '+waNumber) : '' %>. Thank you for choosing <%= siteName %>.
  </div>
</div>
</body></html>

GSZ_INV_EJS

cat > /tmp/gsz15_patch.js <<'GSZ_PATCH_JS'
// Step 15 patches — exact-string, each must match exactly once.
const fs = require('fs');
const APP = process.env.APP || '/opt/gsz';
let fail = 0;

function patch(file, find, repl, label) {
  const p = APP + '/' + file;
  let s = fs.readFileSync(p, 'utf8');
  const n = s.split(find).length - 1;
  if (n !== 1) { console.error('PATCH FAIL [' + label + ']: expected 1 match, found ' + n); fail = 1; return; }
  s = s.replace(find, repl);
  fs.writeFileSync(p, s);
  console.log('[ok] patched ' + label);
}

// 1) Admin sidebar: add Payments link after Orders
patch('views/admin/_shell_top.ejs',
  'Orders</a>\n  </nav>',
  'Orders</a>\n    <a href="/admin/payments" class="<%= on(\'payments\') %>"><svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20"/></svg>Payments</a>\n  </nav>',
  'shell_top payments nav');

// 2) Header nav: wire Resellers link
patch('views/partials/store_top.ejs',
  '<a href="#" data-toast="Resellers page — coming soon.">Resellers</a>',
  '<a href="/resellers">Resellers</a>',
  'store_top resellers link');

// 3) Footer: wire About + Reseller panels
patch('views/partials/store_bottom.ejs',
  '<a href="#" data-toast="About — coming soon.">About us</a>',
  '<a href="/about">About us</a>',
  'footer about link');
patch('views/partials/store_bottom.ejs',
  '<a href="#" data-toast="Resellers — coming soon.">Reseller panels</a>',
  '<a href="/resellers">Reseller panels</a>',
  'footer resellers link');

// 4) Order page: add invoice link before "Back to store"
patch('views/order.ejs',
  '<a class="btn" href="/" style="background:#eef2fe;color:#2a3558;margin-left:8px">Back to store</a>',
  '<a class="btn" href="/order/<%= o.order_no %>/invoice" target="_blank" style="background:#eef2fe;color:#2a3558;margin-left:8px">View / print invoice</a>\n    <a class="btn" href="/" style="background:#eef2fe;color:#2a3558;margin-left:8px">Back to store</a>',
  'order invoice link');

// 5) server.js: mount new routers after adminProductImage
patch('server.js',
  "const adminProductImageRouter = require('./routes/adminProductImage')(pool);\napp.use('/admin', adminProductImageRouter);",
  "const adminProductImageRouter = require('./routes/adminProductImage')(pool);\napp.use('/admin', adminProductImageRouter);\nconst adminPaymentsRouter = require('./routes/adminPayments')(pool);\napp.use('/admin', adminPaymentsRouter);\nconst pagesRouter = require('./routes/pages')(pool);\napp.use('/', pagesRouter);\nconst invoiceRouter = require('./routes/invoice')(pool);\napp.use('/', invoiceRouter);",
  'server.js mounts');

if (fail) { console.error('ONE OR MORE PATCHES FAILED'); process.exit(1); }
console.log('[ok] all patches applied');

GSZ_PATCH_JS
APP="$APP" node /tmp/gsz15_patch.js || { restore; exit 1; }

cat > /tmp/gsz15_bump.js <<'GSZ_BUMP_JS'
const fs=require('fs');
['/opt/gsz/views/partials/store_top.ejs','/opt/gsz/views/partials/store_bottom.ejs'].forEach(function(f){
  let s=fs.readFileSync(f,'utf8');s=s.replace(/(app\.(?:css|js))\?v=\d+/g,'$1?v=15');fs.writeFileSync(f,s);
});
console.log('[ok] asset version -> v=15');
GSZ_BUMP_JS
node /tmp/gsz15_bump.js || { restore; exit 1; }
echo "[ok] files written"

pm2 restart gsz --update-env >/dev/null
sleep 2

OKALL=1
HOME_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/")
HEALTH=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health")
ABOUT=$(curl -s "http://127.0.0.1:$PORT/about" || true)
ABOUT_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/about")
RES_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/resellers")
PAY_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/admin/payments")
HB=$(curl -fsS "http://127.0.0.1:$PORT/" || true)

[ "$HEALTH" = "200" ]                       || { echo "FAIL: health HTTP $HEALTH (app may have crashed)"; OKALL=0; }
[ "$HOME_CODE" = "200" ]                     || { echo "FAIL: home HTTP $HOME_CODE"; OKALL=0; }
[ "$ABOUT_CODE" = "200" ]                    || { echo "FAIL: /about HTTP $ABOUT_CODE"; OKALL=0; }
[ "$RES_CODE" = "200" ]                      || { echo "FAIL: /resellers HTTP $RES_CODE"; OKALL=0; }
grep -q 'About us' <<< "$ABOUT"             || { echo "FAIL: /about content missing"; OKALL=0; }
[ "$PAY_CODE" = "302" ] || [ "$PAY_CODE" = "200" ] || { echo "FAIL: /admin/payments not reachable (HTTP $PAY_CODE)"; OKALL=0; }
grep -q 'app.css?v=15' <<< "$HB"            || { echo "FAIL: version not bumped"; OKALL=0; }

# invoice: test against the newest order if one exists
ONO=$(PSQL -tAc "SELECT order_no FROM orders WHERE order_no IS NOT NULL ORDER BY id DESC LIMIT 1" | tr -d '[:space:]')
if [ -n "$ONO" ]; then
  INV_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/order/$ONO/invoice")
  [ "$INV_CODE" = "200" ] || { echo "FAIL: /order/$ONO/invoice HTTP $INV_CODE"; OKALL=0; }
  echo "[info] invoice tested on order $ONO -> $INV_CODE"
else
  echo "[info] no orders yet; invoice route mounted (will serve once orders exist)"
fi

if [ "$OKALL" != "1" ]; then echo "CHECK FAILED — rolling back"; restore; pm2 logs gsz --lines 20 --nostream || true; exit 1; fi
echo "============================================================"
echo "  STEP 15 OK"
echo "  - Admin → Payments: set real receiving details (sidebar link)."
echo "    http://143.198.209.68:$PORT/admin/payments"
echo "  - /about and /resellers pages are live (nav + footer wired)."
echo "  - Invoice: /order/<no>/invoice (print / Save as PDF)."
echo "  - Assets now ?v=15 (hard-refresh once if cached)."
echo "  NEXT (need your input): auto-verify alert format, fulfillment"
echo "  wiring, and SMTP for emailed invoices."
echo "============================================================"
