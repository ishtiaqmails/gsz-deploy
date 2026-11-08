cd /opt/gsz
node <<'EOFcd /opt/gsz
node <<'EOF'
const fs=require('fs');
(function(){
  const f='/opt/gsz/routes/adminOrders.js';
  const orig=fs.readFileSync(f,'utf8');
  const a='product_name, plan_label, currency, amount_display, amount_pkr, method_name, created_at';
  if(orig.split(a).length-1!==1){ console.log('adminOrders anchor x'+(orig.split(a).length-1)); return; }
  const b=a+", CASE WHEN jsonb_typeof(fields->'items')='array' THEN (SELECT string_agg(e->>'name', ', ') FROM jsonb_array_elements(fields->'items') e) END AS cart_names, CASE WHEN jsonb_typeof(fields->'items')='array' THEN jsonb_array_length(fields->'items') ELSE 0 END AS cart_count";
  fs.writeFileSync(f+'.bak.'+Date.now(),orig); fs.writeFileSync(f,orig.split(a).join(b));
  console.log('patched adminOrders.js');
})();
(function(){
  const ejs=require('/opt/gsz/node_modules/ejs');
  const f='/opt/gsz/views/admin/orders.ejs';
  const orig=fs.readFileSync(f,'utf8');
  const a=`<td data-label="Product"><% var _ci=(r.fields&&r.fields.items); if(Array.isArray(_ci)&&_ci.length){ %><%= _ci.map(function(x){return x.name||'';}).filter(Boolean).join(', ') %><div style="font-size:12px;color:var(--muted)"><%= _ci.length %> items</div><% } else { %><%= r.product_name %><div style="font-size:12px;color:var(--muted)"><%= r.plan_label %></div><% } %></td>`;
  if(orig.split(a).length-1!==1){ console.log('orders.ejs cell x'+(orig.split(a).length-1)); return; }
  const b=`<td data-label="Product"><% if(r.cart_names){ %><%= r.cart_names %><div style="font-size:12px;color:var(--muted)"><%= r.cart_count %> items</div><% } else { %><%= r.product_name %><div style="font-size:12px;color:var(--muted)"><%= r.plan_label %></div><% } %></td>`;
  const s=orig.split(a).join(b);
  try{ ejs.compile(s,{includer:()=>({template:''})}); }catch(e){ console.log('FAIL ejs '+e.message); return; }
  fs.writeFileSync(f+'.bak.'+Date.now(),orig); fs.writeFileSync(f,s);
  console.log('patched orders.ejs');
})();
EOF
if node -c /opt/gsz/routes/adminOrders.js; then echo "adminOrders.js OK"; pm2 restart gsz >/dev/null 2>&1 && echo "gsz restarted" || echo "restart failed"; else echo "SYNTAX ERR -> restoring"; cp $(ls -t /opt/gsz/routes/adminOrders.js.bak.* | head -1) /opt/gsz/routes/adminOrders.js; fi
echo DONE'
const fs=require('fs');
(function(){
  const f='/opt/gsz/routes/adminOrders.js';
  const orig=fs.readFileSync(f,'utf8');
  const a='product_name, plan_label, currency, amount_display, amount_pkr, method_name, created_at';
  if(orig.split(a).length-1!==1){ console.log('adminOrders anchor x'+(orig.split(a).length-1)); return; }
  const b=a+", CASE WHEN jsonb_typeof(fields->'items')='array' THEN (SELECT string_agg(e->>'name', ', ') FROM jsonb_array_elements(fields->'items') e) END AS cart_names, CASE WHEN jsonb_typeof(fields->'items')='array' THEN jsonb_array_length(fields->'items') ELSE 0 END AS cart_count";
  fs.writeFileSync(f+'.bak.'+Date.now(),orig); fs.writeFileSync(f,orig.split(a).join(b));
  console.log('patched adminOrders.js');
})();
(function(){
  const ejs=require('/opt/gsz/node_modules/ejs');
  const f='/opt/gsz/views/admin/orders.ejs';
  const orig=fs.readFileSync(f,'utf8');
  const a=`<td data-label="Product"><% var _ci=(r.fields&&r.fields.items); if(Array.isArray(_ci)&&_ci.length){ %><%= _ci.map(function(x){return x.name||'';}).filter(Boolean).join(', ') %><div style="font-size:12px;color:var(--muted)"><%= _ci.length %> items</div><% } else { %><%= r.product_name %><div style="font-size:12px;color:var(--muted)"><%= r.plan_label %></div><% } %></td>`;
  if(orig.split(a).length-1!==1){ console.log('orders.ejs cell x'+(orig.split(a).length-1)); return; }
  const b=`<td data-label="Product"><% if(r.cart_names){ %><%= r.cart_names %><div style="font-size:12px;color:var(--muted)"><%= r.cart_count %> items</div><% } else { %><%= r.product_name %><div style="font-size:12px;color:var(--muted)"><%= r.plan_label %></div><% } %></td>`;
  const s=orig.split(a).join(b);
  try{ ejs.compile(s,{includer:()=>({template:''})}); }catch(e){ console.log('FAIL ejs '+e.message); return; }
  fs.writeFileSync(f+'.bak.'+Date.now(),orig); fs.writeFileSync(f,s);
  console.log('patched orders.ejs');
})();
EOF
if node -c /opt/gsz/routes/adminOrders.js; then echo "adminOrders.js OK"; pm2 restart gsz >/dev/null 2>&1 && echo "gsz restarted" || echo "restart failed"; else echo "SYNTAX ERR -> restoring"; cp $(ls -t /opt/gsz/routes/adminOrders.js.bak.* | head -1) /opt/gsz/routes/adminOrders.js; fi
echo DONE
