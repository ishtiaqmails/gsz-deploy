#!/usr/bin/env bash
# step69 — Category pagination (12/page) on the storefront category pages.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step69-$TS
mkdir -p "$BAK/routes" "$BAK/views"
cp "$APP/routes/category.js" "$BAK/routes/category.js"
cp "$APP/views/category.ejs" "$BAK/views/category.ejs"
restore(){ echo "!! rollback"; cp "$BAK/routes/category.js" "$APP/routes/category.js"; cp "$BAK/views/category.ejs" "$APP/views/category.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> patch category route + view"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const P=[
  { f:A+'/routes/category.js',
    a:"      const products = await storefront.loadProducts(pool, cat.id);",
    b:"      const _allCat = await storefront.loadProducts(pool, cat.id);\n      const perPage = 12;\n      const total = _allCat.length;\n      const pages = Math.max(1, Math.ceil(total / perPage));\n      let page = parseInt(req.query.page, 10) || 1; if (page < 1) page = 1; if (page > pages) page = pages;\n      const products = _allCat.slice((page - 1) * perPage, page * perPage);" },
  { f:A+'/routes/category.js',
    a:"        siteName, logoFile, waNumber, cats, cat, products, bannerMap, settings, shellJson",
    b:"        siteName, logoFile, waNumber, cats, cat, products, total, page, pages, bannerMap, settings, shellJson" },
  { f:A+'/views/category.ejs',
    a:"<h2><%= cat.name %> <span style=\"color:var(--muted);font-weight:600;font-size:.6em\">(<%= products.length %>)</span></h2>",
    b:"<h2><%= cat.name %> <span style=\"color:var(--muted);font-weight:600;font-size:.6em\">(<%= typeof total!=='undefined'?total:products.length %>)</span></h2>" },
  { f:A+'/views/category.ejs',
    a:"      <p style=\"color:var(--muted)\">No products in this category yet. Please check back soon.</p>\n    <% } %>",
    b:"      <p style=\"color:var(--muted)\">No products in this category yet. Please check back soon.</p>\n    <% } %>\n    <% if (typeof pages!=='undefined' && pages>1) { %>\n    <div class=\"pager\" style=\"display:flex;gap:8px;justify-content:center;margin-top:30px;flex-wrap:wrap\">\n      <% if (page>1) { %><a class=\"btn btn-ghost\" href=\"/category/<%= cat.slug %>?page=<%= page-1 %>\">← Prev</a><% } %>\n      <% for(var pn=1; pn<=pages; pn++){ %><a class=\"btn <%= pn===page?'btn-primary':'btn-ghost' %>\" style=\"min-width:42px;justify-content:center\" href=\"/category/<%= cat.slug %>?page=<%= pn %>\"><%= pn %></a><% } %>\n      <% if (page<pages) { %><a class=\"btn btn-ghost\" href=\"/category/<%= cat.slug %>?page=<%= page+1 %>\">Next →</a><% } %>\n    </div>\n    <% } %>" },
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
node --check "$APP/routes/category.js"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("/opt/gsz/views/category.ejs","utf8"),{filename:"/opt/gsz/views/category.ejs"});console.log("   compiled category.ejs");'

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
CSLUG=$(grep -oE '/category/[a-z0-9-]+' <<<"$H" | head -1 | sed 's#/category/##')
[ -n "$CSLUG" ] || CSLUG="iptv"
CP=$(curl -s -m 15 "http://127.0.0.1:3900/category/$CSLUG" || true)
grep -q '</html>' <<<"$CP" || { echo "!! category page broken"; false; }
if grep -qi 'Category error:' <<<"$CP"; then echo "!! category route threw"; false; fi
trap - ERR
echo "==> step69 OK — category pagination live. Backup: $BAK"
