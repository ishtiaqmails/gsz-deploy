#!/usr/bin/env bash
# step70 — Admin Orders pagination (50/page, preserves the status filter).
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step70-$TS
mkdir -p "$BAK/routes" "$BAK/views/admin"
cp "$APP/routes/adminOrders.js" "$BAK/routes/adminOrders.js"
cp "$APP/views/admin/orders.ejs" "$BAK/views/admin/orders.ejs"
restore(){ echo "!! rollback"; cp "$BAK/routes/adminOrders.js" "$APP/routes/adminOrders.js"; cp "$BAK/views/admin/orders.ejs" "$APP/views/admin/orders.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> patch adminOrders route + orders view"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const P=[
  { f:A+'/routes/adminOrders.js',
    a:"      const rows = (await pool.query(\n        `SELECT id, order_no, status, email, whatsapp, product_name, plan_label, currency, amount_display, amount_pkr, method_name, created_at\n         FROM orders ${where} ORDER BY id DESC LIMIT 300`, params)).rows;",
    b:"      const perPage = 50;\n      const total = (await pool.query(`SELECT count(*)::int n FROM orders ${where}`, params)).rows[0].n;\n      const pages = Math.max(1, Math.ceil(total / perPage));\n      let page = parseInt(req.query.page, 10) || 1; if (page < 1) page = 1; if (page > pages) page = pages;\n      const rows = (await pool.query(\n        `SELECT id, order_no, status, email, whatsapp, product_name, plan_label, currency, amount_display, amount_pkr, method_name, created_at\n         FROM orders ${where} ORDER BY id DESC LIMIT ${perPage} OFFSET ${(page - 1) * perPage}`, params)).rows;" },
  { f:A+'/routes/adminOrders.js',
    a:"      res.render('admin/orders', { rows, counts, status, flash: req.query.ok || null });",
    b:"      res.render('admin/orders', { rows, counts, status, page, pages, total, flash: req.query.ok || null });" },
  { f:A+'/views/admin/orders.ejs',
    a:"  </table>\n</div>\n<%- include('_shell_bottom') %>",
    b:"  </table>\n</div>\n<% if (typeof pages!=='undefined' && pages>1) { var qs=function(p){ return '/admin/orders?'+(status?('status='+status+'&'):'')+'page='+p; }; %>\n<div class=\"pager\" style=\"display:flex;gap:8px;justify-content:center;margin-top:20px;flex-wrap:wrap\">\n  <% if (page>1) { %><a class=\"btn btn-g\" href=\"<%= qs(page-1) %>\">← Prev</a><% } %>\n  <% for(var pn=1; pn<=pages; pn++){ %><a class=\"btn <%= pn===page?'btn-p':'btn-g' %>\" style=\"min-width:40px;justify-content:center\" href=\"<%= qs(pn) %>\"><%= pn %></a><% } %>\n  <% if (page<pages) { %><a class=\"btn btn-g\" href=\"<%= qs(page+1) %>\">Next →</a><% } %>\n</div>\n<% } %>\n<%- include('_shell_bottom') %>" },
];
for(const p of P){
  let s=fs.readFileSync(p.f,'utf8');
  if(s.indexOf(p.b)>=0 && s.indexOf(p.a)<0){ console.log('   skip: '+p.f.split('/').pop()); continue; }
  if(s.indexOf(p.a)<0){ console.error('!! anchor missing in '+p.f); process.exit(2); }
  s=s.split(p.a).join(p.b); fs.writeFileSync(p.f,s);
  console.log('   patched: '+p.f.split('/').pop());
}
NODE

echo "==> node --check + ejs compile"
node --check "$APP/routes/adminOrders.js"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("/opt/gsz/views/admin/orders.ejs","utf8"),{filename:"/opt/gsz/views/admin/orders.ejs"});console.log("   compiled orders.ejs");'
grep -q 'OFFSET' "$APP/routes/adminOrders.js" || { echo "!! pagination query missing"; false; }

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:3900/admin/orders || true)
echo "   /admin/orders -> HTTP $CODE"
[ "$CODE" = "302" ] || [ "$CODE" = "200" ] || { echo "!! orders route error $CODE"; false; }
trap - ERR
echo "==> step70 OK — admin orders pagination live. Backup: $BAK"
