#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON — STEP 23: Admin "Bot mapping" screen
#  Map each site PLAN -> fulfilment source (manual | inventory | bot).
#  Bot plans map to the IMMUTABLE sku + plan_key + type (future-proof).
#  Adds: routes/adminMapping.js, views/admin/mapping.ejs,
#        a "Fulfilment > Bot mapping" nav link, server.js mount.
#  Idempotent + auto-rollback.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views/admin" ] || { echo "ABORT: $APP/views/admin not found"; exit 1; }
cd "$APP"

TS=$(date +%s)
BK="$APP/.bak-step23-$TS"; mkdir -p "$BK"
cp server.js "$BK/server.js"
cp views/admin/_shell_top.ejs "$BK/_shell_top.ejs"
restore(){ echo "!! ROLLBACK"; cp "$BK/server.js" "$APP/server.js" 2>/dev/null || true; cp "$BK/_shell_top.ejs" "$APP/views/admin/_shell_top.ejs" 2>/dev/null || true; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "== Galaxy Subz x Zayron — Step 23 (admin bot-mapping) · port ${PORT:-3900} =="

# ---- 1) files ----
cat > routes/adminMapping.js <<'EOF_MAP_ROUTE'
'use strict';
/* Admin: map each site PLAN to how it is fulfilled.
   source = manual | inventory | bot.
   For bot plans we store the IMMUTABLE bot_sku (+ bot_plan_key + bot_type),
   never the serial/name/position — so re-ordering on the bot can't break it. */
const express = require('express');
const botapi = require('../lib/botapi');

module.exports = function (pool) {
  const router = express.Router();
  function auth(req, res, next) {
    if (req.session && req.session.admin) return next();
    return res.redirect('/admin/login');
  }

  router.get('/mapping', auth, async (req, res) => {
    try {
      const products = (await pool.query(
        `SELECT p.id, p.name, p.slug, c.name AS cat
           FROM products p LEFT JOIN categories c ON c.id = p.category_id
          WHERE p.active ORDER BY p.sort, p.id`)).rows;
      const plans = (await pool.query(
        `SELECT id, product_id, label, price_pkr, source, bot_sku, bot_plan_key, bot_type
           FROM product_plans ORDER BY product_id, sort, id`)).rows;
      const bots = (await pool.query(
        `SELECT sku, name, serial, delivery_type, price_pkr, is_active,
                needs, plans, types, missing
           FROM bot_products ORDER BY missing, name NULLS LAST, sku`)).rows;
      const invRows = (await pool.query(
        `SELECT plan_id, count(*)::int n FROM inventory_items
          WHERE status='available' GROUP BY plan_id`)).rows;
      const inv = {}; invRows.forEach(r => { inv[r.plan_id] = r.n; });
      const byProd = {}; plans.forEach(pl => { (byProd[pl.product_id] = byProd[pl.product_id] || []).push(pl); });
      const botBySku = {}; bots.forEach(b => { botBySku[b.sku] = b; });

      const ping = await botapi.ping();
      const last = (await pool.query("SELECT value FROM settings WHERE key='bot_last_sync'")).rows[0];

      res.render('admin/mapping', {
        products, byProd, bots, botBySku, inv,
        bot: Object.assign({ last_sync: last ? last.value : null, count: bots.length, missing: bots.filter(b => b.missing).length }, ping),
        flash: req.query.ok || null, active: 'mapping', title: 'Bot mapping'
      });
    } catch (e) { res.status(500).send('Mapping error: ' + e.message); }
  });

  router.post('/mapping', auth, express.urlencoded({ extended: true, limit: '2mb' }), async (req, res) => {
    const pl = (req.body && req.body.pl) || {};
    const SRC = ['manual', 'inventory', 'bot'];
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      for (const id of Object.keys(pl)) {
        const pid = parseInt(id, 10); if (!Number.isFinite(pid)) continue;
        const r = pl[id] || {};
        const source = SRC.includes(String(r.source || '')) ? r.source : 'manual';
        let sku = null, pk = null, ty = null;
        if (source === 'bot') {
          sku = (String(r.bot_sku || '').trim()) || null;
          pk = (String(r.bot_plan_key || '').trim()) || null;
          ty = (String(r.bot_type || '').trim()) || null;
        }
        await client.query(
          'UPDATE product_plans SET source=$1, bot_sku=$2, bot_plan_key=$3, bot_type=$4 WHERE id=$5',
          [source, sku, pk, ty, pid]
        );
      }
      await client.query('COMMIT');
      res.redirect('/admin/mapping?ok=' + encodeURIComponent('Mapping saved'));
    } catch (e) {
      try { await client.query('ROLLBACK'); } catch (x) {}
      res.status(500).send('Mapping save error: ' + e.message);
    } finally { client.release(); }
  });

  return router;
};
EOF_MAP_ROUTE
cat > views/admin/mapping.ejs <<'EOF_MAP_VIEW'
<%- include('_shell_top', { active:'mapping', title:'Bot mapping' }) %>
<style>
  .mapwrap{overflow-x:auto}
  table.map{min-width:880px}
  table.map td{vertical-align:middle}
  table.map select{margin-bottom:0}
  .plan-name{font-weight:700}
  .plan-price{color:var(--muted);font-size:12.5px}
  .src-pill{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:700}
  .badge{display:inline-flex;align-items:center;gap:5px;font-size:12px;font-weight:700;border-radius:999px;padding:3px 9px;white-space:nowrap}
  .badge.ok{background:#e9fbf1;color:#0b7a42}
  .badge.warn{background:#fff4e2;color:#9a6400}
  .badge.bad{background:#fdeceb;color:#b4322c}
  .badge.mut{background:#eef1fa;color:#5b6688}
  .botcell[hidden]{display:none}
  .conn{display:flex;align-items:center;gap:14px;flex-wrap:wrap}
  .dot{width:9px;height:9px;border-radius:50%;flex:none}
  .dot.g{background:var(--ok)} .dot.r{background:var(--bad)} .dot.y{background:var(--warn)}
</style>

<% if (flash) { %><div class="flash"><%= flash %></div><% } %>

<!-- connection status -->
<div class="card">
  <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap">
    <div class="conn">
      <% var dotc = !bot.configured ? 'y' : (bot.reachable ? 'g' : 'r'); %>
      <span class="dot <%= dotc %>"></span>
      <div>
        <b>Reseller bot link:
          <%= !bot.configured ? 'not configured yet' : (bot.reachable ? 'connected' : 'unreachable') %></b>
        <div class="sub" style="margin:2px 0 0">
          <% if (!bot.configured) { %>
            Add <code>GSZ_BOT_API_URL</code> + <code>GSZ_BOT_API_KEY</code> to <code>.env</code>, then Sync.
          <% } else if (!bot.reachable) { %>
            Configured but the API didn't answer<%= bot.error ? ' ('+bot.error+')' : '' %>.
          <% } else { %>
            <%= bot.productCount %> products live on the bot.
          <% } %>
          · <%= bot.count %> cached<% if (bot.missing) { %> · <span style="color:var(--bad);font-weight:700"><%= bot.missing %> missing</span><% } %>
          <% if (bot.last_sync) { %> · last sync <%= new Date(bot.last_sync).toLocaleString('en-GB') %><% } %>
        </div>
      </div>
    </div>
    <form method="post" action="/admin/bot/sync" style="margin:0">
      <button class="btn btn-g" type="submit">↻ Sync from bot</button>
    </form>
  </div>
</div>

<p class="sub" style="margin:0 0 18px">
  Choose how each plan is fulfilled. <b>Reseller bot</b> maps to the bot's immutable <code>sku</code> (+ plan &amp; type for IPTV),
  so renaming or re-ordering products on the bot never breaks it. <b>My inventory</b> delivers from this site's own stock pool.
  <b>Manual</b> = you deliver by hand.
</p>

<form method="post" action="/admin/mapping">
<% products.forEach(function(p){ var plans=(byProd[p.id]||[]); if(!plans.length) return; %>
  <div class="card">
    <h2 style="margin:0 0 2px"><%= p.name %></h2>
    <div class="sub" style="margin:0 0 14px"><%= p.cat || '—' %> · <%= plans.length %> plan<%= plans.length>1?'s':'' %></div>
    <div class="mapwrap">
      <table class="map">
        <thead><tr>
          <th style="width:190px">Plan</th><th style="width:150px">Source</th>
          <th>Bot product</th><th style="width:150px">Bot plan</th><th style="width:130px">Type</th>
          <th style="width:150px">Status</th>
        </tr></thead>
        <tbody>
        <% plans.forEach(function(pl){ var isBot = pl.source==='bot'; %>
          <tr data-plan="<%= pl.id %>">
            <td><div class="plan-name"><%= pl.label %></div><div class="plan-price">Rs <%= Math.round(pl.price_pkr).toLocaleString('en-US') %></div></td>
            <td>
              <select name="pl[<%= pl.id %>][source]" class="js-src">
                <option value="manual"    <%= pl.source==='manual'    ?'selected':'' %>>Manual</option>
                <option value="inventory" <%= pl.source==='inventory' ?'selected':'' %>>My inventory</option>
                <option value="bot"       <%= pl.source==='bot'       ?'selected':'' %>>Reseller bot</option>
              </select>
            </td>
            <td class="botcell" <%= isBot?'':'hidden' %>>
              <select name="pl[<%= pl.id %>][bot_sku]" class="js-sku">
                <option value="">— choose product —</option>
                <% bots.forEach(function(b){ %>
                  <option value="<%= b.sku %>" <%= pl.bot_sku===b.sku?'selected':'' %>>
                    <%= b.name || b.sku %><%= b.missing?' (MISSING)':'' %> · <%= b.sku %></option>
                <% }); %>
              </select>
            </td>
            <td class="botcell" <%= isBot?'':'hidden' %>>
              <select name="pl[<%= pl.id %>][bot_plan_key]" class="js-plan" data-cur="<%= pl.bot_plan_key||'' %>"></select>
            </td>
            <td class="botcell" <%= isBot?'':'hidden' %>>
              <select name="pl[<%= pl.id %>][bot_type]" class="js-type" data-cur="<%= pl.bot_type||'' %>"></select>
            </td>
            <td><span class="badge mut js-status">—</span></td>
          </tr>
        <% }); %>
        </tbody>
      </table>
    </div>
  </div>
<% }); %>

  <div style="position:sticky;bottom:0;padding:14px 0;background:linear-gradient(0deg,var(--bg) 55%,transparent)">
    <button class="btn btn-p" type="submit">Save mapping</button>
    <span class="sub" style="margin-left:12px">Pricing &amp; stock stay live from the bot; this only sets the fulfilment route.</span>
  </div>
</form>

<script>
var BOT = <%- JSON.stringify(botBySku || {}) %>;
function opt(v,label,sel){ var o=document.createElement('option'); o.value=v; o.textContent=label; if(sel)o.selected=true; return o; }
function fillPlanType(row){
  var sku=row.querySelector('.js-sku').value;
  var planSel=row.querySelector('.js-plan'), typeSel=row.querySelector('.js-type');
  var b=BOT[sku];
  var curPlan=planSel.getAttribute('data-cur')||'', curType=typeSel.getAttribute('data-cur')||'';
  planSel.innerHTML=''; typeSel.innerHTML='';
  var plans=(b&&b.plans)||[], types=(b&&b.types)||[];
  if(!plans.length){ planSel.appendChild(opt('','— n/a —',true)); planSel.disabled=true; }
  else { planSel.disabled=false; planSel.appendChild(opt('','— choose —',!curPlan));
    plans.forEach(function(p){ planSel.appendChild(opt(p.plan_key, p.label+(p.price!=null?(' · Rs '+p.price):''), String(p.plan_key)===curPlan)); }); }
  if(!types.length){ typeSel.appendChild(opt('','— n/a —',true)); typeSel.disabled=true; }
  else { typeSel.disabled=false; typeSel.appendChild(opt('','— choose —',!curType));
    types.forEach(function(t){ typeSel.appendChild(opt(t.key, t.label||t.key, String(t.key)===curType)); }); }
}
function status(row){
  var src=row.querySelector('.js-src').value, el=row.querySelector('.js-status');
  el.className='badge';
  if(src==='manual'){ el.classList.add('mut'); el.textContent='Manual'; return; }
  if(src==='inventory'){ el.classList.add('mut'); el.textContent='Own inventory'; return; }
  var sku=row.querySelector('.js-sku').value, b=BOT[sku];
  if(!sku){ el.classList.add('warn'); el.textContent='⚠ not mapped'; return; }
  if(!b){ el.classList.add('warn'); el.textContent='⚠ sync needed'; return; }
  if(b.missing){ el.classList.add('bad'); el.textContent='⚠ missing on bot'; return; }
  el.classList.add('ok'); el.textContent=(b.delivery_type||'mapped');
}
function sync(row){
  var src=row.querySelector('.js-src').value;
  row.querySelectorAll('.botcell').forEach(function(c){ c.hidden = (src!=='bot'); });
  if(src==='bot') fillPlanType(row);
  status(row);
}
document.querySelectorAll('tr[data-plan]').forEach(function(row){
  sync(row);
  row.querySelector('.js-src').addEventListener('change',function(){ sync(row); });
  row.querySelector('.js-sku').addEventListener('change',function(){
    row.querySelector('.js-plan').setAttribute('data-cur','');
    row.querySelector('.js-type').setAttribute('data-cur','');
    fillPlanType(row); status(row);
  });
});
</script>

<%- include('_shell_bottom') %>
EOF_MAP_VIEW
echo "[ok] files written"

# ---- 2) nav link in _shell_top.ejs (idempotent, exact-anchor count===1) ----
node <<'EOF_NAV_PATCH'
const fs=require('fs'), f='views/admin/_shell_top.ejs';
let s=fs.readFileSync(f,'utf8');
if(s.includes('/admin/mapping')){ console.log('nav already present'); process.exit(0); }
const anchor='>Payments</a>';
const c=s.split(anchor).length-1;
if(c!==1){ console.error('nav anchor count '+c+' (expected 1)'); process.exit(1); }
const add='\n    <div class="grp">Fulfilment</div>\n    <a href="/admin/mapping" class="<%= on(\'mapping\') %>"><svg viewBox="0 0 24 24"><path d="M9 17H7A5 5 0 0 1 7 7h2"/><path d="M15 7h2a5 5 0 0 1 0 10h-2"/><path d="M8 12h8"/></svg>Bot mapping</a>';
fs.writeFileSync(f, s.replace(anchor, anchor+add));
console.log('nav link added');
EOF_NAV_PATCH

# ---- 3) mount adminMapping in server.js (idempotent, exact-anchor count===1) ----
node <<'EOF_MOUNT'
const fs=require('fs'), f='server.js';
let s=fs.readFileSync(f,'utf8');
if(s.includes('routes/adminMapping')){ console.log('already mounted'); process.exit(0); }
const anchor="app.use('/admin', botAdminRouter);";
const c=s.split(anchor).length-1;
if(c!==1){ console.error('mount anchor count '+c+' (expected 1)'); process.exit(1); }
const add="\nconst adminMappingRouter = require('./routes/adminMapping')(pool);\napp.use('/admin', adminMappingRouter);";
fs.writeFileSync(f, s.replace(anchor, anchor+add));
console.log('mounted adminMapping');
EOF_MOUNT

# ---- 4) checks ----
node --check routes/adminMapping.js
node --check server.js
node <<'EOF_COMPILE'
const ejs=require('ejs'), fs=require('fs');
ejs.compile(fs.readFileSync('views/admin/mapping.ejs','utf8'), {filename: process.cwd()+'/views/admin/mapping.ejs'});
console.log('ejs compile ok');
EOF_COMPILE
echo "[ok] syntax + template"

# ---- 5) restart + health ----
pm2 restart gsz >/dev/null 2>&1 || pm2 start server.js --name gsz >/dev/null 2>&1
sleep 2
BODY="$(curl -fsS "http://127.0.0.1:${PORT:-3900}/" 2>/dev/null || true)"
grep -q "</html>" <<< "$BODY" || { echo "!! health check failed (home page)"; exit 1; }
CODE="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT:-3900}/admin/mapping" || true)"
echo "   /admin/mapping -> HTTP $CODE (302 to login = OK)"
echo "[ok] site healthy"

trap - ERR
echo "============================================================"
echo "  STEP 23 OK — Admin > Fulfilment > Bot mapping is live."
echo "  Open /admin/mapping: set each plan's source; bot plans map to"
echo "  sku + plan_key + type. Click 'Sync from bot' once the bot API"
echo "  is configured in .env to populate the product dropdowns."
echo "  Next: Step 24 = checkout adapts to delivery_type + stock gating."
echo "============================================================"
