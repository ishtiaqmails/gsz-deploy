#!/usr/bin/env bash
# stepOrderStatus2.sh — enrich the order monitor: accurate failure placement + reason,
# and a full "Fulfillment & verification" panel. Pure display, uses existing columns.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=views/admin/order_detail.ejs
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .gszm_p.js .gszm_v.js; exit 1; }
trap restore ERR

echo "==> enriching $F"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
const file = 'views/admin/order_detail.ejs';
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf('_failIdx') >= 0) { console.log('  already enriched'); process.exit(0); }
function one(a, b, label) {
  const n = s.split(a).length - 1;
  if (n !== 1) throw new Error(label + ': anchor x' + n + ' (need 1)');
  s = s.split(a).join(b);
  console.log('  ' + label + ': ok');
}

// 1) smarter stage/failure logic
const A1 = `      var _bad = (_s==='rejected'||_s==='failed'||_s==='cancelled');
      var _vs = (!!o.verified_at) || (['paid','approved','delivering','delivered','completed','done'].indexOf(_s)>=0);
      var _del = (['delivered','completed','done'].indexOf(_s)>=0) || (!!o.delivered_at);
      var _done = 1 + (_vs?1:0) + (_del?2:0);
      function _ostState(i){ if(_bad && i===1) return 'bad'; if(_bad && i>1) return 'todo'; if(i < _done) return 'done'; if(i === _done) return 'active'; return 'todo'; }`;
const B1 = `      var _cr = String(o.claim_result||'');
      var _vs = (!!o.verified_at) || (_cr==='genuine') || (['paid','approved','delivering','delivered','completed','done'].indexOf(_s)>=0);
      var _del = (['delivered','completed','done'].indexOf(_s)>=0) || (!!o.delivered_at);
      var _rejected = (_s==='rejected'||_s==='cancelled');
      var _failed = (_s==='failed');
      var _failIdx = _rejected ? 1 : (_failed ? (_vs ? 2 : 1) : -1);
      var _bad = (_failIdx>=0);
      var _done = 1 + (_vs?1:0) + (_del?2:0);
      function _ostState(i){ if(_failIdx>=0){ if(i<_failIdx) return 'done'; if(i===_failIdx) return 'bad'; return 'todo'; } if(i < _done) return 'done'; if(i === _done) return 'active'; return 'todo'; }
      function _reason(){ if(!_cr || _cr==='genuine'){ return _failIdx===2 ? 'Payment was verified genuine, but fulfillment did not complete - the provider/panel likely rejected it or was out of stock.' : 'The payment was not accepted.'; } return _cr; }`;
one(A1, B1, 'stage logic');

// 2) richer failure banner (reason + raw code)
const A2 = `      <% if(_bad){ %><div class="ost-ban">This order was <%= _s==='failed'?'marked failed':(_s==='cancelled'?'cancelled':'rejected') %> - it did not complete.</div><% } %>`;
const B2 = `      <% if(_bad){ %><div class="ost-ban"><b>This order <%= _s==='failed'?'failed':(_s==='cancelled'?'was cancelled':'was rejected') %>.</b><br><%= _reason() %><% if(_cr && _cr!=='genuine'){ %><br><span style="font-family:ui-monospace,Menlo,monospace;font-size:11px;opacity:.85">reason code: <%= _cr %></span><% } %></div><% } %>`;
one(A2, B2, 'failure banner');

// 3) full fulfillment & verification card, before Update status
const A3 = `    <div class="card">
      <h2 style="margin-bottom:12px">Update status</h2>`;
const CARD = `    <% 
      var _bf = o.bot_fields; if(typeof _bf==='string'){ try{_bf=JSON.parse(_bf);}catch(e){_bf=null;} }
      var _fj = o.fields; if(typeof _fj==='string'){ try{_fj=JSON.parse(_fj);}catch(e){_fj=null;} }
      var _alerts = String(o.owner_alerts||'').split(',').filter(function(x){return x;});
      function _amt(n){ if(n==null||n==='') return '-'; return 'Rs ' + Number(n).toLocaleString('en-US'); }
    %>
    <div class="card">
      <h2 style="margin-bottom:12px">Fulfillment &amp; verification</h2>
      <table><tbody>
        <tr><td style="color:var(--muted);width:140px">Source</td><td><%= o.source==='bot' ? 'Reseller bot (auto)' : (o.source==='cart'?'Cart (auto)':'Manual') %></td></tr>
        <% if(o.bot_order_id){ %><tr><td style="color:var(--muted)">Bot order ID</td><td><%= o.bot_order_id %></td></tr><% } %>
        <% if(o.bot_sku){ %><tr><td style="color:var(--muted)">SKU / plan</td><td><%= o.bot_sku %><%= o.bot_plan_key?(' · '+o.bot_plan_key):'' %><%= o.bot_type?(' · '+o.bot_type):'' %></td></tr><% } %>
        <tr><td style="color:var(--muted)">Payment check</td><td><%= o.claim_result==='genuine' ? 'Verified genuine' : (o.claim_result? o.claim_result : 'Not verified yet') %></td></tr>
        <tr><td style="color:var(--muted)">Amount claimed</td><td><%= _amt(o.amount_claimed) %><% if(o.amount_pkr!=null){ %> <span style="color:var(--muted)">/ order <%= _amt(o.amount_pkr) %></span><% } %></td></tr>
        <% if(_bf && _bf.plan){ %><tr><td style="color:var(--muted)">Plan</td><td><%= _bf.plan %></td></tr><% } %>
        <% if(_bf && _bf.expiry){ %><tr><td style="color:var(--muted)">Expiry</td><td><%= _bf.expiry %></td></tr><% } %>
        <% if(_fj && _fj.screenshotHash){ %><tr><td style="color:var(--muted)">Proof hash</td><td style="font-family:ui-monospace,Menlo,monospace;font-size:11px"><%= String(_fj.screenshotHash).slice(0,16) %>…</td></tr><% } %>
        <% if(_alerts.length){ %><tr><td style="color:var(--muted)">Alerts sent</td><td style="text-transform:capitalize"><%= _alerts.join(', ') %></td></tr><% } %>
      </tbody></table>
    </div>
`;
one(A3, CARD + A3, 'fulfillment card');

fs.writeFileSync(file, s);
console.log('  written');
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
echo "DONE — full order monitor: accurate stages, failure reason, and fulfillment panel."
