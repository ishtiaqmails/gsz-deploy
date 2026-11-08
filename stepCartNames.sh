cd /opt/gsz
node <<'EOF'
const fs=require('fs'), ejs=require('/opt/gsz/node_modules/ejs');
function save(f,s,orig){ try{ ejs.compile(s,{includer:()=>({template:''})}); }catch(e){ console.log('FAIL ejs '+f+': '+e.message); return false; } fs.writeFileSync(f+'.bak.'+Date.now(),orig); fs.writeFileSync(f,s); return true; }
(function(){
  const f='/opt/gsz/views/admin/order_detail.ejs';
  const orig=fs.readFileSync(f,'utf8');
  const re=/(<td style="color:var\(--muted\);width:150px">Product<\/td><td style="font-weight:600">)<%= o\.product_name %>[\s\S]*?<%= o\.plan_label %>(<\/td>)/;
  if(!re.test(orig)){ console.log('order_detail: Product row not matched'); return; }
  const inner=`<% var _it=(o.fields&&o.fields.items); if(Array.isArray(_it)&&_it.length){ _it.forEach(function(x,_i){ %><%= (_i?', ':'')+(x.name||'') %><% if(x.plan_label){ %> <span style="color:var(--muted);font-weight:400">(<%= x.plan_label %>)</span><% } }); } else { %><%= o.product_name %> &mdash; <%= o.plan_label %><% } %>`;
  const s=orig.replace(re,'$1'+inner+'$2');
  if(save(f,s,orig)) console.log('OK order_detail.ejs');
})();
(function(){
  const f='/opt/gsz/views/admin/orders.ejs';
  const orig=fs.readFileSync(f,'utf8');
  const a=`<td data-label="Product"><%= r.product_name %><div style="font-size:12px;color:var(--muted)"><%= r.plan_label %></div></td>`;
  if(orig.split(a).length-1!==1){ console.log('orders.ejs: anchor not unique'); return; }
  const b=`<td data-label="Product"><% var _ci=(r.fields&&r.fields.items); if(Array.isArray(_ci)&&_ci.length){ %><%= _ci.map(function(x){return x.name||'';}).filter(Boolean).join(', ') %><div style="font-size:12px;color:var(--muted)"><%= _ci.length %> items</div><% } else { %><%= r.product_name %><div style="font-size:12px;color:var(--muted)"><%= r.plan_label %></div><% } %></td>`;
  if(save(f,orig.split(a).join(b),orig)) console.log('OK orders.ejs');
})();
EOF
pm2 restart gsz >/dev/null 2>&1 && echo "gsz restarted" || echo "restart failed"
echo "=== orders LIST query has fields? ==="
grep -nE "fields|product_name|FROM orders" routes/adminOrders.js 2>/dev/null | head -12
echo "=== device idle logic ==="
grep -rnE "idle|last_seen|seen_at|heartbeat|device|agent" routes/iptv.js 2>/dev/null | head -18
grep -nE "idle|device|seen|phone|online|active" views/admin/iptv.ejs 2>/dev/null | head -12
echo DONE
