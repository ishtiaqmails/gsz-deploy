#!/usr/bin/env bash
# stepOrderStatus.sh — admin order_detail: add a clear "Order status" timeline above Update-status.
# Placed -> Payment verified -> Fulfilling -> Delivered, with checkmarks, timestamps (PKT) and a
# red banner for failed/rejected. Pure display; uses existing columns (created_at/verified_at/delivered_at).
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=views/admin/order_detail.ejs
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .gszm_p.js .gszm_v.js; exit 1; }
trap restore ERR

echo "==> patching $F (order status timeline)"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
const file = 'views/admin/order_detail.ejs';
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf('class="ost"') >= 0) { console.log('  already patched'); process.exit(0); }
const A = `    <div class="card">
      <h2 style="margin-bottom:12px">Update status</h2>`;
const TL = `    <% 
      var _s = String(o.status||'').toLowerCase();
      var _bad = (_s==='rejected'||_s==='failed'||_s==='cancelled');
      var _vs = (!!o.verified_at) || (['paid','approved','delivering','delivered','completed','done'].indexOf(_s)>=0);
      var _del = (['delivered','completed','done'].indexOf(_s)>=0) || (!!o.delivered_at);
      var _done = 1 + (_vs?1:0) + (_del?2:0);
      function _ostState(i){ if(_bad && i===1) return 'bad'; if(_bad && i>1) return 'todo'; if(i < _done) return 'done'; if(i === _done) return 'active'; return 'todo'; }
      function _ostFmt(d){ if(!d) return ''; try{ return new Date(d).toLocaleString('en-GB',{timeZone:'Asia/Karachi',day:'2-digit',month:'short',hour:'2-digit',minute:'2-digit'}); }catch(e){ return ''; } }
      var _ostSteps = [ {k:'Placed', t:o.created_at}, {k:'Payment verified', t:o.verified_at}, {k:'Fulfilling', t:null}, {k:'Delivered', t:o.delivered_at} ];
      var _ostSb = (typeof SB!=='undefined' && SB[_s]) ? SB[_s] : ['#eef1f6','#667'];
    %>
    <style>
    .ost{position:relative}
    .ost-row{display:flex;gap:12px;position:relative;padding-bottom:18px}
    .ost-row:last-child{padding-bottom:0}
    .ost-row::before{content:'';position:absolute;left:13px;top:28px;bottom:-2px;width:2px;background:var(--hair)}
    .ost-row:last-child::before{display:none}
    .ost-row.ost-done::before{background:#16b765}
    .ost-dot{flex:none;width:28px;height:28px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:700;border:2px solid var(--hair);background:#fff;color:var(--muted);z-index:1}
    .ost-done .ost-dot{background:#16b765;border-color:#16b765;color:#fff}
    .ost-active .ost-dot{border-color:var(--brand);color:var(--brand);box-shadow:0 0 0 4px rgba(42,123,255,.14)}
    .ost-bad .ost-dot{background:#e0453f;border-color:#e0453f;color:#fff}
    .ost-k{font-weight:700;font-size:14px}
    .ost-todo .ost-k{color:var(--muted);font-weight:600}
    .ost-t{font-size:12px;color:var(--muted);margin-top:2px}
    .ost-active .ost-t{color:var(--brand);font-weight:600}
    .ost-ban{background:#fdecec;color:#b42318;border:1px solid #f6c9c6;border-radius:10px;padding:9px 12px;font-size:13px;font-weight:600;margin:0 0 14px}
    </style>
    <div class="card">
      <div style="display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:14px">
        <h2 style="margin:0">Order status</h2>
        <span style="background:<%= _ostSb[0] %>;color:<%= _ostSb[1] %>;padding:3px 12px;border-radius:999px;font-size:12px;font-weight:700;text-transform:capitalize"><%= _s || '-' %></span>
      </div>
      <% if(_bad){ %><div class="ost-ban">This order was <%= _s==='failed'?'marked failed':(_s==='cancelled'?'cancelled':'rejected') %> - it did not complete.</div><% } %>
      <div class="ost">
        <% _ostSteps.forEach(function(stp,i){ var stt=_ostState(i); var tt=_ostFmt(stp.t); %>
          <div class="ost-row ost-<%= stt %>">
            <span class="ost-dot"><%= stt==='done'?'✓':(stt==='bad'?'✕':String(i+1)) %></span>
            <div>
              <div class="ost-k"><%= stp.k %></div>
              <% if(stt==='active' && !tt){ %><div class="ost-t">In progress…</div><% } else if(tt){ %><div class="ost-t"><%= tt %></div><% } else if(stt==='todo'){ %><div class="ost-t">Pending</div><% } %>
            </div>
          </div>
        <% }); %>
      </div>
    </div>
`;
const n = s.split(A).length - 1;
if (n !== 1) throw new Error('anchor x' + n + ' (need 1)');
s = s.split(A).join(TL + A);
fs.writeFileSync(file, s);
console.log('  injected order-status timeline');
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
echo "DONE — each order now shows a clear status timeline above the Update-status buttons."
