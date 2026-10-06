#!/usr/bin/env bash
# step64 — Bulk downloads: add a download (label+url) to all selected products
# from the products-list toolbar. Extends /products/bulk.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step64-$TS
PRODS_MD5="a5c80e12eff00a495de02fb5654a4ee0"
mkdir -p "$BAK/routes" "$BAK/views/admin"
cp "$APP/routes/adminCatalog.js" "$BAK/routes/adminCatalog.js"
cp "$APP/views/admin/products.ejs" "$BAK/views/admin/products.ejs"
restore(){ echo "!! rollback"; cp "$BAK/routes/adminCatalog.js" "$APP/routes/adminCatalog.js"; cp "$BAK/views/admin/products.ejs" "$APP/views/admin/products.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> write admin products.ejs"
cat > /tmp/s64_prods.b64 <<'B64P'
PCUtIGluY2x1ZGUoJ19zaGVsbF90b3AnLCB7IGFjdGl2ZToncHJvZHVjdHMnLCB0aXRsZTonUHJvZHVjdHMnIH0pICU+CjxkaXYgc3R5bGU9ImRpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjE0cHg7bWFyZ2luLWJvdHRvbTo2cHgiPgogIDxkaXYgc3R5bGU9ImZsZXg6MSI+PHAgY2xhc3M9InN1YiI+QWRkLCBlZGl0LCByZW9yZGVyLCBzaG93L2hpZGUgb3IgcmVtb3ZlIHByb2R1Y3RzLiBUaGUgb3JkZXIgaGVyZSBpcyB0aGUgb3JkZXIgY3VzdG9tZXJzIHNlZS48L3A+PC9kaXY+CiAgPGEgY2xhc3M9ImJ0biBidG4tcCIgaHJlZj0iL2FkbWluL3Byb2R1Y3RzL25ldyI+KyBBZGQgcHJvZHVjdDwvYT4KPC9kaXY+CjwlIGlmIChmbGFzaCkgeyAlPjxkaXYgY2xhc3M9ImZsYXNoIj48JT0gZmxhc2ggJT48L2Rpdj48JSB9ICU+Cjxmb3JtIGlkPSJidWxrZiIgbWV0aG9kPSJwb3N0IiBhY3Rpb249Ii9hZG1pbi9wcm9kdWN0cy9idWxrIj48L2Zvcm0+CjxkaXYgY2xhc3M9ImNhcmQiIHN0eWxlPSJkaXNwbGF5OmZsZXg7Z2FwOjEwcHg7YWxpZ24taXRlbXM6Y2VudGVyO2ZsZXgtd3JhcDp3cmFwO21hcmdpbi1ib3R0b206MTRweCI+CiAgPGIgc3R5bGU9ImZvbnQtc2l6ZToxNHB4Ij5CdWxrIG5vdGU6PC9iPgogIDxpbnB1dCBmb3JtPSJidWxrZiIgdHlwZT0idGV4dCIgbmFtZT0ibm90ZSIgcGxhY2Vob2xkZXI9Ik5vdGUgdG8gYXBwbHkgdG8gdGhlIHNlbGVjdGVkIHByb2R1Y3RzIiBzdHlsZT0iZmxleDoxO21pbi13aWR0aDoyMjBweDttYXJnaW46MCI+CiAgPGJ1dHRvbiBmb3JtPSJidWxrZiIgbmFtZT0ib3AiIHZhbHVlPSJzZXQiIGNsYXNzPSJidG4gYnRuLXAiIHR5cGU9InN1Ym1pdCI+QXBwbHkgdG8gc2VsZWN0ZWQ8L2J1dHRvbj4KICA8YnV0dG9uIGZvcm09ImJ1bGtmIiBuYW1lPSJvcCIgdmFsdWU9ImNsZWFyIiBjbGFzcz0iYnRuIGJ0bi1nIiB0eXBlPSJzdWJtaXQiPkNsZWFyIG5vdGUgb24gc2VsZWN0ZWQ8L2J1dHRvbj4KPC9kaXY+CjxkaXYgY2xhc3M9ImNhcmQiIHN0eWxlPSJkaXNwbGF5OmZsZXg7Z2FwOjEwcHg7YWxpZ24taXRlbXM6Y2VudGVyO2ZsZXgtd3JhcDp3cmFwO21hcmdpbi1ib3R0b206MTRweCI+CiAgPGIgc3R5bGU9ImZvbnQtc2l6ZToxNHB4Ij5CdWxrIGRvd25sb2FkOjwvYj4KICA8aW5wdXQgZm9ybT0iYnVsa2YiIHR5cGU9InRleHQiIG5hbWU9ImRsX2xhYmVsIiBwbGFjZWhvbGRlcj0iTGFiZWwgKGUuZy4gRG93bmxvYWQgQVBLKSIgc3R5bGU9Im1pbi13aWR0aDoxNjBweDttYXJnaW46MCI+CiAgPGlucHV0IGZvcm09ImJ1bGtmIiB0eXBlPSJ0ZXh0IiBuYW1lPSJkbF91cmwiIHBsYWNlaG9sZGVyPSJodHRwczovLy4uLiIgc3R5bGU9ImZsZXg6MTttaW4td2lkdGg6MjAwcHg7bWFyZ2luOjAiPgogIDxidXR0b24gZm9ybT0iYnVsa2YiIG5hbWU9Im9wIiB2YWx1ZT0iYWRkLWRvd25sb2FkIiBjbGFzcz0iYnRuIGJ0bi1wIiB0eXBlPSJzdWJtaXQiPkFkZCBkb3dubG9hZCB0byBzZWxlY3RlZDwvYnV0dG9uPgo8L2Rpdj4KPGRpdiBjbGFzcz0iY2FyZCIgc3R5bGU9InBhZGRpbmc6MDtvdmVyZmxvdzpoaWRkZW4iPgogIDx0YWJsZT4KICAgIDx0aGVhZD48dHI+PHRoIHN0eWxlPSJ3aWR0aDozNHB4Ij48aW5wdXQgdHlwZT0iY2hlY2tib3giIGlkPSJzZWxhbGwiIHRpdGxlPSJTZWxlY3QgYWxsIj48L3RoPjx0aCBzdHlsZT0id2lkdGg6NzBweCI+T3JkZXI8L3RoPjx0aD5Qcm9kdWN0PC90aD48dGg+Q2F0ZWdvcnk8L3RoPjx0aD5Gcm9tPC90aD48dGg+VHJlbmRpbmc8L3RoPjx0aD5TdGF0dXM8L3RoPjx0aCBzdHlsZT0idGV4dC1hbGlnbjpyaWdodCI+QWN0aW9uczwvdGg+PC90cj48L3RoZWFkPgogICAgPHRib2R5PgogICAgPCUgcm93cy5mb3JFYWNoKGZ1bmN0aW9uKHIsIGkpeyAlPgogICAgICA8dHI+CiAgICAgICAgPHRkPjxpbnB1dCB0eXBlPSJjaGVja2JveCIgbmFtZT0iaWRzIiB2YWx1ZT0iPCU9IHIuaWQgJT4iIGZvcm09ImJ1bGtmIj48L3RkPgogICAgICAgIDx0ZCBzdHlsZT0id2hpdGUtc3BhY2U6bm93cmFwIj4KICAgICAgICAgIDxmb3JtIG1ldGhvZD0icG9zdCIgYWN0aW9uPSIvYWRtaW4vcHJvZHVjdHMvPCU9IHIuaWQgJT4vbW92ZT9kaXI9dXAiIHN0eWxlPSJkaXNwbGF5OmlubGluZSI+PGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1nIiBzdHlsZT0icGFkZGluZzo1cHggOXB4IiB0eXBlPSJzdWJtaXQiIHRpdGxlPSJNb3ZlIHVwIiA8JT0gaT09PTA/J2Rpc2FibGVkJzonJyAlPj7ihpE8L2J1dHRvbj48L2Zvcm0+CiAgICAgICAgICA8Zm9ybSBtZXRob2Q9InBvc3QiIGFjdGlvbj0iL2FkbWluL3Byb2R1Y3RzLzwlPSByLmlkICU+L21vdmU/ZGlyPWRvd24iIHN0eWxlPSJkaXNwbGF5OmlubGluZSI+PGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1nIiBzdHlsZT0icGFkZGluZzo1cHggOXB4IiB0eXBlPSJzdWJtaXQiIHRpdGxlPSJNb3ZlIGRvd24iIDwlPSBpPT09KHJvd3MubGVuZ3RoLTEpPydkaXNhYmxlZCc6JycgJT4+4oaTPC9idXR0b24+PC9mb3JtPgogICAgICAgIDwvdGQ+CiAgICAgICAgPHRkIHN0eWxlPSJmb250LXdlaWdodDo2MDAiPjwlPSByLm5hbWUgJT48L3RkPgogICAgICAgIDx0ZCBzdHlsZT0iY29sb3I6dmFyKC0tbXV0ZWQpIj48JT0gci5jYXQgfHwgJ+KAlCcgJT48L3RkPgogICAgICAgIDx0ZD5ScyA8JT0gci5wcmljZSA/IE1hdGgucm91bmQoci5wcmljZSkudG9Mb2NhbGVTdHJpbmcoJ2VuLVVTJykgOiAn4oCUJyAlPjwvdGQ+CiAgICAgICAgPHRkPgogICAgICAgICAgPGZvcm0gbWV0aG9kPSJwb3N0IiBhY3Rpb249Ii9hZG1pbi9wcm9kdWN0cy88JT0gci5pZCAlPi90cmVuZGluZyIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIj4KICAgICAgICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1nIiBzdHlsZT0icGFkZGluZzo2cHggMTFweDs8JT0gci50cmVuZGluZyA/ICdjb2xvcjojZjViMzAxO2ZvbnQtd2VpZ2h0OjcwMCcgOiAnY29sb3I6dmFyKC0tbXV0ZWQpJyAlPiIgdHlwZT0ic3VibWl0IiB0aXRsZT0iPCU9IHIudHJlbmRpbmcgPyAnUmVtb3ZlIGZyb20gVHJlbmRpbmcnIDogJ01hcmsgYXMgVHJlbmRpbmcnICU+Ij48JT0gci50cmVuZGluZyA/ICfimIUgVHJlbmRpbmcnIDogJ+KYhiBNYXJrJyAlPjwvYnV0dG9uPgogICAgICAgICAgPC9mb3JtPgogICAgICAgIDwvdGQ+CiAgICAgICAgPHRkPjwlIGlmIChyLmhpZGRlbiB8fCAhci5hY3RpdmUpIHsgJT48c3BhbiBzdHlsZT0iY29sb3I6I2I0MjMxODtmb250LXdlaWdodDo2MDAiPkhpZGRlbjwvc3Bhbj48JSB9IGVsc2UgeyAlPjxzcGFuIHN0eWxlPSJjb2xvcjojMGI3YTQyO2ZvbnQtd2VpZ2h0OjYwMCI+TGl2ZTwvc3Bhbj48JSB9ICU+PC90ZD4KICAgICAgICA8dGQgc3R5bGU9InRleHQtYWxpZ246cmlnaHQ7d2hpdGUtc3BhY2U6bm93cmFwIj4KICAgICAgICAgIDxhIGNsYXNzPSJidG4gYnRuLWciIHN0eWxlPSJwYWRkaW5nOjZweCAxMXB4IiBocmVmPSIvYWRtaW4vcHJvZHVjdHMvPCU9IHIuaWQgJT4vZWRpdCI+RWRpdDwvYT4KICAgICAgICAgIDxmb3JtIG1ldGhvZD0icG9zdCIgYWN0aW9uPSIvYWRtaW4vcHJvZHVjdHMvPCU9IHIuaWQgJT4vdG9nZ2xlIiBzdHlsZT0iZGlzcGxheTppbmxpbmUiPjxidXR0b24gY2xhc3M9ImJ0biBidG4tZyIgc3R5bGU9InBhZGRpbmc6NnB4IDExcHgiIHR5cGU9InN1Ym1pdCI+PCU9IChyLmhpZGRlbnx8IXIuYWN0aXZlKSA/ICdTaG93JyA6ICdIaWRlJyAlPjwvYnV0dG9uPjwvZm9ybT4KICAgICAgICAgIDxmb3JtIG1ldGhvZD0icG9zdCIgYWN0aW9uPSIvYWRtaW4vcHJvZHVjdHMvPCU9IHIuaWQgJT4vZGVsZXRlIiBzdHlsZT0iZGlzcGxheTppbmxpbmUiIG9uc3VibWl0PSJyZXR1cm4gY29uZmlybSgnRGVsZXRlIHRoaXMgcHJvZHVjdCBwZXJtYW5lbnRseT8nKSI+PGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1nIiBzdHlsZT0icGFkZGluZzo2cHggMTFweDtjb2xvcjojYjQyMzE4IiB0eXBlPSJzdWJtaXQiPkRlbGV0ZTwvYnV0dG9uPjwvZm9ybT4KICAgICAgICA8L3RkPgogICAgICA8L3RyPgogICAgPCUgfSk7ICU+CiAgICA8L3Rib2R5PgogIDwvdGFibGU+CjwvZGl2Pgo8c2NyaXB0PgooZnVuY3Rpb24oKXt2YXIgc2E9ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3NlbGFsbCcpO2lmKCFzYSlyZXR1cm47c2EuYWRkRXZlbnRMaXN0ZW5lcignY2hhbmdlJyxmdW5jdGlvbigpe2RvY3VtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJ2lucHV0W25hbWU9ImlkcyJdJykuZm9yRWFjaChmdW5jdGlvbihjKXtjLmNoZWNrZWQ9c2EuY2hlY2tlZDt9KTt9KTt9KSgpOwo8L3NjcmlwdD4KPCUtIGluY2x1ZGUoJ19zaGVsbF9ib3R0b20nKSAlPgo=
B64P
base64 -d /tmp/s64_prods.b64 > "$APP/views/admin/products.ejs"; rm -f /tmp/s64_prods.b64
G=$(md5sum "$APP/views/admin/products.ejs"|awk '{print $1}'); echo "   products.ejs $G (expect $PRODS_MD5)"
[ "$G" = "$PRODS_MD5" ] || { echo "!! md5 mismatch"; false; }

echo "==> extend /products/bulk route (add-download)"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/routes/adminCatalog.js';
let s=fs.readFileSync(f,'utf8');
const a="    else if (op === 'clear') { await pool.query('UPDATE products SET note=NULL WHERE id = ANY()', [ids]); }";
const b=a+"\n    else if (op === 'add-download') {\n      const lab = (req.body.dl_label || '').trim(), url = (req.body.dl_url || '').trim();\n      if (lab && url) for (const pid of ids) await pool.query('INSERT INTO product_downloads(product_id,label,url,sort) VALUES(,,,COALESCE((SELECT MAX(sort)+1 FROM product_downloads WHERE product_id=),0))', [pid, lab, url]);\n    }";
if(s.indexOf("op === 'add-download'")>=0){ console.log('   skip (already)'); }
else { if(s.indexOf(a)<0){ console.error('!! anchor missing (bulk clear)'); process.exit(2); } s=s.replace(a,b); fs.writeFileSync(f,s); console.log('   add-download handled'); }
NODE

echo "==> node --check + ejs compile"
node --check "$APP/routes/adminCatalog.js"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("/opt/gsz/views/admin/products.ejs","utf8"),{filename:"/opt/gsz/views/admin/products.ejs"});console.log("   compiled products.ejs");'
grep -q "op === 'add-download'" "$APP/routes/adminCatalog.js" || { echo "!! add-download missing"; false; }

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:3900/admin/products || true)
echo "   /admin/products -> HTTP $CODE"
[ "$CODE" = "302" ] || [ "$CODE" = "200" ] || { echo "!! admin error $CODE"; false; }
trap - ERR
echo "==> step64 OK — bulk downloads live. Backup: $BAK"
