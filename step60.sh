#!/usr/bin/env bash
# step60 — Trending toggle (#): mark products as trending; home Trending row shows
# them (fallback to auto-pick when none marked). Admin toggle + indicator.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step60-$TS
PRODS_MD5="5ccf0bafe86bae30e0d9f8b7b46135f1"
mkdir -p "$BAK/lib" "$BAK/routes" "$BAK/views/admin"
cp "$APP/lib/storefront.js" "$BAK/lib/storefront.js"
cp "$APP/views/home.ejs" "$BAK/views/home.ejs"
cp "$APP/routes/adminCatalog.js" "$BAK/routes/adminCatalog.js"
cp "$APP/views/admin/products.ejs" "$BAK/views/admin/products.ejs"
restore(){ echo "!! rollback";
  cp "$BAK/lib/storefront.js" "$APP/lib/storefront.js"
  cp "$BAK/views/home.ejs" "$APP/views/home.ejs"
  cp "$BAK/routes/adminCatalog.js" "$APP/routes/adminCatalog.js"
  cp "$BAK/views/admin/products.ejs" "$APP/views/admin/products.ejs"
  pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> migration: products.trending"
( sudo -u postgres psql -d gsz -c "ALTER TABLE products ADD COLUMN IF NOT EXISTS trending boolean NOT NULL DEFAULT false;" 2>&1   || psql -U gsz_user -d gsz -c "ALTER TABLE products ADD COLUMN IF NOT EXISTS trending boolean NOT NULL DEFAULT false;" 2>&1 ) | tail -1

echo "==> patch storefront.js / home.ejs / adminCatalog.js"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const patches=[
  { f:A+'/lib/storefront.js',
    a:"p.name, p.short_desc AS descr, p.image,",
    b:"p.name, p.short_desc AS descr, p.image, p.trending," },
  { f:A+'/lib/storefront.js',
    a:"from:Number(r.from_price||0), plans:r.plan_count||0 }));",
    b:"from:Number(r.from_price||0), plans:r.plan_count||0, trending:!!r.trending }));" },
  { f:A+'/views/home.ejs',
    a:"var trending = products.slice(0,8);",
    b:"var trending = products.filter(function(p){return p.trending;}); if(!trending.length) trending = products.slice(0,8);" },
  { f:A+'/routes/adminCatalog.js',
    a:"SELECT p.id, p.name, p.slug, p.active, p.hidden, c.name AS cat,",
    b:"SELECT p.id, p.name, p.slug, p.active, p.hidden, p.trending, c.name AS cat," },
  { f:A+'/routes/adminCatalog.js',
    a:"    res.redirect('/admin/products?ok=Order+updated');\n  });",
    b:"    res.redirect('/admin/products?ok=Order+updated');\n  });\n  router.post('/products/:id/trending', auth, async (req, res) => {\n    await pool.query('UPDATE products SET trending = NOT trending WHERE id=$1', [req.params.id]);\n    res.redirect('/admin/products?ok=Trending+updated');\n  });" },
];
for(const p of patches){
  let s=fs.readFileSync(p.f,'utf8');
  if(s.indexOf(p.b)>=0 && s.indexOf(p.a)<0){ console.log('   skip (already): '+p.f.split('/').pop()); continue; }
  if(s.indexOf(p.a)<0){ console.error('!! anchor missing in '+p.f+' :: '+p.a.slice(0,40)); process.exit(2); }
  s=s.split(p.a).join(p.b); fs.writeFileSync(p.f,s);
  console.log('   patched: '+p.f.split('/').pop());
}
NODE

echo "==> write admin products.ejs"
cat > /tmp/s60_prods.b64 <<'B64P'
PCUtIGluY2x1ZGUoJ19zaGVsbF90b3AnLCB7IGFjdGl2ZToncHJvZHVjdHMnLCB0aXRsZTonUHJvZHVjdHMnIH0pICU+CjxkaXYgc3R5bGU9ImRpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjE0cHg7bWFyZ2luLWJvdHRvbTo2cHgiPgogIDxkaXYgc3R5bGU9ImZsZXg6MSI+PHAgY2xhc3M9InN1YiI+QWRkLCBlZGl0LCByZW9yZGVyLCBzaG93L2hpZGUgb3IgcmVtb3ZlIHByb2R1Y3RzLiBUaGUgb3JkZXIgaGVyZSBpcyB0aGUgb3JkZXIgY3VzdG9tZXJzIHNlZS48L3A+PC9kaXY+CiAgPGEgY2xhc3M9ImJ0biBidG4tcCIgaHJlZj0iL2FkbWluL3Byb2R1Y3RzL25ldyI+KyBBZGQgcHJvZHVjdDwvYT4KPC9kaXY+CjwlIGlmIChmbGFzaCkgeyAlPjxkaXYgY2xhc3M9ImZsYXNoIj48JT0gZmxhc2ggJT48L2Rpdj48JSB9ICU+CjxkaXYgY2xhc3M9ImNhcmQiIHN0eWxlPSJwYWRkaW5nOjA7b3ZlcmZsb3c6aGlkZGVuIj4KICA8dGFibGU+CiAgICA8dGhlYWQ+PHRyPjx0aCBzdHlsZT0id2lkdGg6NzBweCI+T3JkZXI8L3RoPjx0aD5Qcm9kdWN0PC90aD48dGg+Q2F0ZWdvcnk8L3RoPjx0aD5Gcm9tPC90aD48dGg+VHJlbmRpbmc8L3RoPjx0aD5TdGF0dXM8L3RoPjx0aCBzdHlsZT0idGV4dC1hbGlnbjpyaWdodCI+QWN0aW9uczwvdGg+PC90cj48L3RoZWFkPgogICAgPHRib2R5PgogICAgPCUgcm93cy5mb3JFYWNoKGZ1bmN0aW9uKHIsIGkpeyAlPgogICAgICA8dHI+CiAgICAgICAgPHRkIHN0eWxlPSJ3aGl0ZS1zcGFjZTpub3dyYXAiPgogICAgICAgICAgPGZvcm0gbWV0aG9kPSJwb3N0IiBhY3Rpb249Ii9hZG1pbi9wcm9kdWN0cy88JT0gci5pZCAlPi9tb3ZlP2Rpcj11cCIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIj48YnV0dG9uIGNsYXNzPSJidG4gYnRuLWciIHN0eWxlPSJwYWRkaW5nOjVweCA5cHgiIHR5cGU9InN1Ym1pdCIgdGl0bGU9Ik1vdmUgdXAiIDwlPSBpPT09MD8nZGlzYWJsZWQnOicnICU+PuKGkTwvYnV0dG9uPjwvZm9ybT4KICAgICAgICAgIDxmb3JtIG1ldGhvZD0icG9zdCIgYWN0aW9uPSIvYWRtaW4vcHJvZHVjdHMvPCU9IHIuaWQgJT4vbW92ZT9kaXI9ZG93biIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIj48YnV0dG9uIGNsYXNzPSJidG4gYnRuLWciIHN0eWxlPSJwYWRkaW5nOjVweCA5cHgiIHR5cGU9InN1Ym1pdCIgdGl0bGU9Ik1vdmUgZG93biIgPCU9IGk9PT0ocm93cy5sZW5ndGgtMSk/J2Rpc2FibGVkJzonJyAlPj7ihpM8L2J1dHRvbj48L2Zvcm0+CiAgICAgICAgPC90ZD4KICAgICAgICA8dGQgc3R5bGU9ImZvbnQtd2VpZ2h0OjYwMCI+PCU9IHIubmFtZSAlPjwvdGQ+CiAgICAgICAgPHRkIHN0eWxlPSJjb2xvcjp2YXIoLS1tdXRlZCkiPjwlPSByLmNhdCB8fCAn4oCUJyAlPjwvdGQ+CiAgICAgICAgPHRkPlJzIDwlPSByLnByaWNlID8gTWF0aC5yb3VuZChyLnByaWNlKS50b0xvY2FsZVN0cmluZygnZW4tVVMnKSA6ICfigJQnICU+PC90ZD4KICAgICAgICA8dGQ+CiAgICAgICAgICA8Zm9ybSBtZXRob2Q9InBvc3QiIGFjdGlvbj0iL2FkbWluL3Byb2R1Y3RzLzwlPSByLmlkICU+L3RyZW5kaW5nIiBzdHlsZT0iZGlzcGxheTppbmxpbmUiPgogICAgICAgICAgICA8YnV0dG9uIGNsYXNzPSJidG4gYnRuLWciIHN0eWxlPSJwYWRkaW5nOjZweCAxMXB4OzwlPSByLnRyZW5kaW5nID8gJ2NvbG9yOiNmNWIzMDE7Zm9udC13ZWlnaHQ6NzAwJyA6ICdjb2xvcjp2YXIoLS1tdXRlZCknICU+IiB0eXBlPSJzdWJtaXQiIHRpdGxlPSI8JT0gci50cmVuZGluZyA/ICdSZW1vdmUgZnJvbSBUcmVuZGluZycgOiAnTWFyayBhcyBUcmVuZGluZycgJT4iPjwlPSByLnRyZW5kaW5nID8gJ+KYhSBUcmVuZGluZycgOiAn4piGIE1hcmsnICU+PC9idXR0b24+CiAgICAgICAgICA8L2Zvcm0+CiAgICAgICAgPC90ZD4KICAgICAgICA8dGQ+PCUgaWYgKHIuaGlkZGVuIHx8ICFyLmFjdGl2ZSkgeyAlPjxzcGFuIHN0eWxlPSJjb2xvcjojYjQyMzE4O2ZvbnQtd2VpZ2h0OjYwMCI+SGlkZGVuPC9zcGFuPjwlIH0gZWxzZSB7ICU+PHNwYW4gc3R5bGU9ImNvbG9yOiMwYjdhNDI7Zm9udC13ZWlnaHQ6NjAwIj5MaXZlPC9zcGFuPjwlIH0gJT48L3RkPgogICAgICAgIDx0ZCBzdHlsZT0idGV4dC1hbGlnbjpyaWdodDt3aGl0ZS1zcGFjZTpub3dyYXAiPgogICAgICAgICAgPGEgY2xhc3M9ImJ0biBidG4tZyIgc3R5bGU9InBhZGRpbmc6NnB4IDExcHgiIGhyZWY9Ii9hZG1pbi9wcm9kdWN0cy88JT0gci5pZCAlPi9lZGl0Ij5FZGl0PC9hPgogICAgICAgICAgPGZvcm0gbWV0aG9kPSJwb3N0IiBhY3Rpb249Ii9hZG1pbi9wcm9kdWN0cy88JT0gci5pZCAlPi90b2dnbGUiIHN0eWxlPSJkaXNwbGF5OmlubGluZSI+PGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1nIiBzdHlsZT0icGFkZGluZzo2cHggMTFweCIgdHlwZT0ic3VibWl0Ij48JT0gKHIuaGlkZGVufHwhci5hY3RpdmUpID8gJ1Nob3cnIDogJ0hpZGUnICU+PC9idXR0b24+PC9mb3JtPgogICAgICAgICAgPGZvcm0gbWV0aG9kPSJwb3N0IiBhY3Rpb249Ii9hZG1pbi9wcm9kdWN0cy88JT0gci5pZCAlPi9kZWxldGUiIHN0eWxlPSJkaXNwbGF5OmlubGluZSIgb25zdWJtaXQ9InJldHVybiBjb25maXJtKCdEZWxldGUgdGhpcyBwcm9kdWN0IHBlcm1hbmVudGx5PycpIj48YnV0dG9uIGNsYXNzPSJidG4gYnRuLWciIHN0eWxlPSJwYWRkaW5nOjZweCAxMXB4O2NvbG9yOiNiNDIzMTgiIHR5cGU9InN1Ym1pdCI+RGVsZXRlPC9idXR0b24+PC9mb3JtPgogICAgICAgIDwvdGQ+CiAgICAgIDwvdHI+CiAgICA8JSB9KTsgJT4KICAgIDwvdGJvZHk+CiAgPC90YWJsZT4KPC9kaXY+CjwlLSBpbmNsdWRlKCdfc2hlbGxfYm90dG9tJykgJT4K
B64P
base64 -d /tmp/s60_prods.b64 > "$APP/views/admin/products.ejs"; rm -f /tmp/s60_prods.b64
G=$(md5sum "$APP/views/admin/products.ejs"|awk '{print $1}'); echo "   products.ejs $G (expect $PRODS_MD5)"
[ "$G" = "$PRODS_MD5" ] || { echo "!! md5 mismatch"; false; }

echo "==> node --check + ejs compile"
node --check "$APP/lib/storefront.js"
node --check "$APP/routes/adminCatalog.js"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");["views/home.ejs","views/admin/products.ejs"].forEach(function(f){ejs.compile(fs.readFileSync("/opt/gsz/"+f,"utf8"),{filename:"/opt/gsz/"+f});console.log("   compiled "+f);});'
grep -q "products/:id/trending" "$APP/routes/adminCatalog.js" || { echo "!! trending route missing"; false; }

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
grep -q 'max-width:560px){#cats .catgrid' <<<"$H" || { echo "!! step52 mobile catgrid rule lost"; false; }
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:3900/admin/products || true)
echo "   /admin/products -> HTTP $CODE"
[ "$CODE" = "302" ] || [ "$CODE" = "200" ] || { echo "!! admin products error $CODE"; false; }
trap - ERR
echo "==> step60 OK — trending toggle live. Backup: $BAK"
