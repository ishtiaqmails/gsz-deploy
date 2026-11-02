#!/usr/bin/env bash
# stepOrderStatus3.sh — swap the Fulfillment panel's <table> for a clean flex key/value layout
# (the admin's responsive table CSS mangles tables on narrow screens). Splice-replaces the card.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=views/admin/order_detail.ejs
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .gszm_p.js .gszm_v.js; exit 1; }
trap restore ERR

echo "==> swapping fulfillment table -> flex rows"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
const file = 'views/admin/order_detail.ejs';
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf('class="fv-row"') >= 0) { console.log('  already flex'); process.exit(0); }
const START = `    <% 
      var _bf = o.bot_fields;`;
const UPD = `    <div class="card">
      <h2 style="margin-bottom:12px">Update status</h2>`;
const i0 = s.indexOf(START);
const i1 = s.indexOf(UPD);
if (i0 < 0 || i1 < 0 || i1 < i0) throw new Error('markers not found (i0=' + i0 + ', i1=' + i1 + ')');
const CARD = `    <% 
      var _bf = o.bot_fields; if(typeof _bf==='string'){ try{_bf=JSON.parse(_bf);}catch(e){_bf=null;} }
      var _fj = o.fields; if(typeof _fj==='string'){ try{_fj=JSON.parse(_fj);}catch(e){_fj=null;} }
      var _alerts = String(o.owner_alerts||'').split(',').filter(function(x){return x;});
      function _amt(n){ if(n==null||n==='') return '-'; return 'Rs ' + Number(n).toLocaleString('en-US'); }
    %>
    <style>
    .fv-row{display:flex;justify-content:space-between;gap:16px;padding:10px 0;border-bottom:1px solid var(--hair);font-size:14px}
    .fv-row:first-child{padding-top:0}
    .fv-row:last-child{border-bottom:none;padding-bottom:0}
    .fv-k{color:var(--muted);flex:none}
    .fv-v{text-align:right;font-weight:600;word-break:break-word}
    </style>
    <div class="card">
      <h2 style="margin-bottom:8px">Fulfillment &amp; verification</h2>
      <div class="fv">
        <div class="fv-row"><span class="fv-k">Source</span><span class="fv-v"><%= o.source==='bot' ? 'Reseller bot (auto)' : (o.source==='cart'?'Cart (auto)':'Manual') %></span></div>
        <% if(o.bot_order_id){ %><div class="fv-row"><span class="fv-k">Bot order ID</span><span class="fv-v"><%= o.bot_order_id %></span></div><% } %>
        <% if(o.bot_sku){ %><div class="fv-row"><span class="fv-k">SKU / plan</span><span class="fv-v"><%= o.bot_sku %><%= o.bot_plan_key?(' · '+o.bot_plan_key):'' %><%= o.bot_type?(' · '+o.bot_type):'' %></span></div><% } %>
        <div class="fv-row"><span class="fv-k">Payment check</span><span class="fv-v"><%= o.claim_result==='genuine' ? 'Verified genuine' : (o.claim_result? o.claim_result : 'Not verified yet') %></span></div>
        <div class="fv-row"><span class="fv-k">Amount claimed</span><span class="fv-v"><%= _amt(o.amount_claimed) %><% if(o.amount_pkr!=null){ %> <span style="color:var(--muted);font-weight:500">/ order <%= _amt(o.amount_pkr) %></span><% } %></span></div>
        <% if(_bf && _bf.plan){ %><div class="fv-row"><span class="fv-k">Plan</span><span class="fv-v"><%= _bf.plan %></span></div><% } %>
        <% if(_bf && _bf.expiry){ %><div class="fv-row"><span class="fv-k">Expiry</span><span class="fv-v"><%= _bf.expiry %></span></div><% } %>
        <% if(_fj && _fj.screenshotHash){ %><div class="fv-row"><span class="fv-k">Proof hash</span><span class="fv-v" style="font-family:ui-monospace,Menlo,monospace;font-size:11px;font-weight:500"><%= String(_fj.screenshotHash).slice(0,16) %>…</span></div><% } %>
        <% if(_alerts.length){ %><div class="fv-row"><span class="fv-k">Alerts sent</span><span class="fv-v" style="text-transform:capitalize"><%= _alerts.join(', ') %></span></div><% } %>
      </div>
    </div>
`;
s = s.slice(0, i0) + CARD + s.slice(i1);
fs.writeFileSync(file, s);
console.log('  fulfillment panel now flex key/value');
JS
node .gszm_p.js

echo "==> validating"
cat > .gszm_v.js <<'JS'
const ejs = require('ejs'), fs = require('fs');
ejs.compile(fs.readFileSync('views/admin/order_detail.ejs', 'utf8'), { filename: 'views/admin/order_detail.ejs' });
console.log('  order_detail.ejs compiles');
JS
node .gszm_v.js
rm -f .gszm_p.js .gszm_v.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — fulfillment panel is now clean on phone and desktop."
