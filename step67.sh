#!/usr/bin/env bash
# step67 — Reviews admin: add/edit/approve/delete customer reviews.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step67-$TS
mkdir -p "$BAK/routes" "$BAK/views/admin"
cp "$APP/routes/adminCatalog.js" "$BAK/routes/adminCatalog.js"
cp "$APP/views/admin/_shell_top.ejs" "$BAK/views/admin/_shell_top.ejs"
restore(){ echo "!! rollback"; cp "$BAK/routes/adminCatalog.js" "$APP/routes/adminCatalog.js"; cp "$BAK/views/admin/_shell_top.ejs" "$APP/views/admin/_shell_top.ejs"; rm -f "$APP/views/admin/reviews.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR
writef(){ local dest="$APP/$1" b64="$2" md5="$3"; base64 -d "$b64" > "$dest"; local got; got=$(md5sum "$dest"|awk '{print $1}'); echo "   $1 $got $([ "$got" = "$md5" ] && echo OK || echo MISMATCH)"; [ "$got" = "$md5" ] || { echo "!! md5 mismatch $1"; false; }; }
cat > /tmp/s67_reviews.b64 <<'B67_reviews'
PCUtIGluY2x1ZGUoJ19zaGVsbF90b3AnLCB7IGFjdGl2ZToncmV2aWV3cycsIHRpdGxlOidSZXZpZXdzJyB9KSAlPgo8cCBjbGFzcz0ic3ViIiBzdHlsZT0ibWFyZ2luLWJvdHRvbToxOHB4Ij5BZGQsIGVkaXQsIGFwcHJvdmUgb3IgZGVsZXRlIGN1c3RvbWVyIHJldmlld3MuIE9ubHkgPGI+YXBwcm92ZWQ8L2I+IHJldmlld3Mgc2hvdyBvbiB0aGUgc2l0ZS48L3A+CjwlIGlmIChmbGFzaCkgeyAlPjxkaXYgY2xhc3M9ImZsYXNoIj48JT0gZmxhc2ggJT48L2Rpdj48JSB9ICU+CjxkaXYgY2xhc3M9ImNhcmQiPgogIDxoMj5BZGQgYSByZXZpZXc8L2gyPgogIDxmb3JtIG1ldGhvZD0icG9zdCIgYWN0aW9uPSIvYWRtaW4vcmV2aWV3cy9zYXZlIiBzdHlsZT0iZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1uczoxZnIgMWZyIDkwcHg7Z2FwOjEwcHg7YWxpZ24taXRlbXM6ZW5kIj4KICAgIDxkaXY+PGxhYmVsIGNsYXNzPSJmbGQiPkF1dGhvcjwvbGFiZWw+PGlucHV0IHR5cGU9InRleHQiIG5hbWU9ImF1dGhvciIgcGxhY2Vob2xkZXI9ImUuZy4gQWhzYW4gUi4iIHJlcXVpcmVkIHN0eWxlPSJtYXJnaW46MCI+PC9kaXY+CiAgICA8ZGl2PjxsYWJlbCBjbGFzcz0iZmxkIj5Mb2NhdGlvbjwvbGFiZWw+PGlucHV0IHR5cGU9InRleHQiIG5hbWU9ImxvY2F0aW9uIiBwbGFjZWhvbGRlcj0iZS5nLiBLYXJhY2hpIiBzdHlsZT0ibWFyZ2luOjAiPjwvZGl2PgogICAgPGRpdj48bGFiZWwgY2xhc3M9ImZsZCI+U3RhcnM8L2xhYmVsPgogICAgICA8c2VsZWN0IG5hbWU9InN0YXJzIiBzdHlsZT0ibWFyZ2luOjAiPjwlIGZvcih2YXIgaT01O2k+PTE7aS0tKXsgJT48b3B0aW9uIHZhbHVlPSI8JT0gaSAlPiI+PCU9IGkgJT48L29wdGlvbj48JSB9ICU+PC9zZWxlY3Q+PC9kaXY+CiAgICA8ZGl2IHN0eWxlPSJncmlkLWNvbHVtbjoxLzQiPjxsYWJlbCBjbGFzcz0iZmxkIj5SZXZpZXc8L2xhYmVsPjx0ZXh0YXJlYSBuYW1lPSJib2R5IiByb3dzPSIyIiBwbGFjZWhvbGRlcj0iV2hhdCB0aGUgY3VzdG9tZXIgc2FpZCIgcmVxdWlyZWQ+PC90ZXh0YXJlYT48L2Rpdj4KICAgIDxsYWJlbCBzdHlsZT0iZ3JpZC1jb2x1bW46MS8zO2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjhweDtmb250LXNpemU6MTRweDtmb250LXdlaWdodDo2MDAiPjxpbnB1dCB0eXBlPSJjaGVja2JveCIgbmFtZT0iYXBwcm92ZWQiIGNoZWNrZWQgc3R5bGU9IndpZHRoOmF1dG87bWFyZ2luOjAiPiBBcHByb3ZlZCAoc2hvdyBvbiBzaXRlKTwvbGFiZWw+CiAgICA8YnV0dG9uIGNsYXNzPSJidG4gYnRuLXAiIHR5cGU9InN1Ym1pdCIgc3R5bGU9ImdyaWQtY29sdW1uOjMvNCI+QWRkIHJldmlldzwvYnV0dG9uPgogIDwvZm9ybT4KPC9kaXY+CjxkaXYgY2xhc3M9ImNhcmQiIHN0eWxlPSJwYWRkaW5nOjA7b3ZlcmZsb3c6aGlkZGVuIj4KICA8dGFibGU+CiAgICA8dGhlYWQ+PHRyPjx0aD5BdXRob3IgLyBMb2NhdGlvbjwvdGg+PHRoIHN0eWxlPSJ3aWR0aDo3MHB4Ij5TdGFyczwvdGg+PHRoPlJldmlldzwvdGg+PHRoIHN0eWxlPSJ3aWR0aDo5MHB4Ij5TdGF0dXM8L3RoPjx0aCBzdHlsZT0idGV4dC1hbGlnbjpyaWdodCI+QWN0aW9uczwvdGg+PC90cj48L3RoZWFkPgogICAgPHRib2R5PgogICAgPCUgcm93cy5mb3JFYWNoKGZ1bmN0aW9uKHIpeyAlPgogICAgICA8dHI+CiAgICAgICAgPHRkPgogICAgICAgICAgPGZvcm0gaWQ9InJ2ZjwlPSByLmlkICU+IiBtZXRob2Q9InBvc3QiIGFjdGlvbj0iL2FkbWluL3Jldmlld3Mvc2F2ZSI+PC9mb3JtPgogICAgICAgICAgPGlucHV0IGZvcm09InJ2ZjwlPSByLmlkICU+IiB0eXBlPSJoaWRkZW4iIG5hbWU9ImlkIiB2YWx1ZT0iPCU9IHIuaWQgJT4iPgogICAgICAgICAgPGlucHV0IGZvcm09InJ2ZjwlPSByLmlkICU+IiB0eXBlPSJ0ZXh0IiBuYW1lPSJhdXRob3IiIHZhbHVlPSI8JT0gci5hdXRob3IgfHwgJycgJT4iIHJlcXVpcmVkIHN0eWxlPSJtYXJnaW46MCAwIDZweDtmb250LXdlaWdodDo2MDA7bWluLXdpZHRoOjEzMHB4Ij4KICAgICAgICAgIDxpbnB1dCBmb3JtPSJydmY8JT0gci5pZCAlPiIgdHlwZT0idGV4dCIgbmFtZT0ibG9jYXRpb24iIHZhbHVlPSI8JT0gci5sb2NhdGlvbiB8fCAnJyAlPiIgcGxhY2Vob2xkZXI9IkxvY2F0aW9uIiBzdHlsZT0ibWFyZ2luOjA7bWluLXdpZHRoOjEzMHB4Ij4KICAgICAgICA8L3RkPgogICAgICAgIDx0ZD4KICAgICAgICAgIDxzZWxlY3QgZm9ybT0icnZmPCU9IHIuaWQgJT4iIG5hbWU9InN0YXJzIiBzdHlsZT0ibWFyZ2luOjAiPjwlIGZvcih2YXIgaT01O2k+PTE7aS0tKXsgJT48b3B0aW9uIHZhbHVlPSI8JT0gaSAlPiIgPCU9IChyLnN0YXJzPT09aSk/J3NlbGVjdGVkJzonJyAlPj48JT0gaSAlPjwvb3B0aW9uPjwlIH0gJT48L3NlbGVjdD4KICAgICAgICA8L3RkPgogICAgICAgIDx0ZD48aW5wdXQgZm9ybT0icnZmPCU9IHIuaWQgJT4iIHR5cGU9InRleHQiIG5hbWU9ImJvZHkiIHZhbHVlPSI8JT0gKHIuYm9keXx8JycpLnJlcGxhY2UoLyIvZywnJnF1b3Q7JykgJT4iIHN0eWxlPSJtYXJnaW46MDt3aWR0aDoxMDAlO21pbi13aWR0aDoyMjBweCI+PC90ZD4KICAgICAgICA8dGQ+PCUgaWYgKHIuYXBwcm92ZWQpIHsgJT48c3BhbiBzdHlsZT0iY29sb3I6IzBiN2E0Mjtmb250LXdlaWdodDo2MDAiPkxpdmU8L3NwYW4+PCUgfSBlbHNlIHsgJT48c3BhbiBzdHlsZT0iY29sb3I6IzlhNjQwMDtmb250LXdlaWdodDo2MDAiPlBlbmRpbmc8L3NwYW4+PCUgfSAlPjwvdGQ+CiAgICAgICAgPHRkIHN0eWxlPSJ0ZXh0LWFsaWduOnJpZ2h0O3doaXRlLXNwYWNlOm5vd3JhcCI+CiAgICAgICAgICA8aW5wdXQgZm9ybT0icnZmPCU9IHIuaWQgJT4iIHR5cGU9ImhpZGRlbiIgbmFtZT0iYXBwcm92ZWQiIHZhbHVlPSI8JT0gci5hcHByb3ZlZCA/ICdvbicgOiAnJyAlPiI+CiAgICAgICAgICA8YnV0dG9uIGZvcm09InJ2ZjwlPSByLmlkICU+IiBjbGFzcz0iYnRuIGJ0bi1wIiBzdHlsZT0icGFkZGluZzo2cHggMTFweCIgdHlwZT0ic3VibWl0Ij5TYXZlPC9idXR0b24+CiAgICAgICAgICA8Zm9ybSBtZXRob2Q9InBvc3QiIGFjdGlvbj0iL2FkbWluL3Jldmlld3MvPCU9IHIuaWQgJT4vYXBwcm92ZSIgc3R5bGU9ImRpc3BsYXk6aW5saW5lIj48YnV0dG9uIGNsYXNzPSJidG4gYnRuLWciIHN0eWxlPSJwYWRkaW5nOjZweCAxMXB4IiB0eXBlPSJzdWJtaXQiPjwlPSByLmFwcHJvdmVkID8gJ1VuYXBwcm92ZScgOiAnQXBwcm92ZScgJT48L2J1dHRvbj48L2Zvcm0+CiAgICAgICAgICA8Zm9ybSBtZXRob2Q9InBvc3QiIGFjdGlvbj0iL2FkbWluL3Jldmlld3MvPCU9IHIuaWQgJT4vZGVsZXRlIiBzdHlsZT0iZGlzcGxheTppbmxpbmUiIG9uc3VibWl0PSJyZXR1cm4gY29uZmlybSgnRGVsZXRlIHRoaXMgcmV2aWV3PycpIj48YnV0dG9uIGNsYXNzPSJidG4gYnRuLWciIHN0eWxlPSJwYWRkaW5nOjZweCAxMXB4O2NvbG9yOiNiNDIzMTgiIHR5cGU9InN1Ym1pdCI+RGVsZXRlPC9idXR0b24+PC9mb3JtPgogICAgICAgIDwvdGQ+CiAgICAgIDwvdHI+CiAgICA8JSB9KTsgJT4KICAgIDwvdGJvZHk+CiAgPC90YWJsZT4KPC9kaXY+CjwlLSBpbmNsdWRlKCdfc2hlbGxfYm90dG9tJykgJT4K
B67_reviews
writef "views/admin/reviews.ejs" /tmp/s67_reviews.b64 "4d4dcea516804f90e6ba69347faa9a4b"
rm -f /tmp/s67_reviews.b64

echo "==> add reviews routes + nav link"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const P=[
  { f:A+'/routes/adminCatalog.js',
    a:"  return router;\n};",
    b:"  // ---- reviews ----\n  router.get('/reviews', auth, async (req, res) => {\n    const rows = (await pool.query('SELECT id,author,location,stars,body,approved FROM reviews ORDER BY id DESC')).rows;\n    res.render('admin/reviews', { rows, flash: req.query.ok || null, active: 'reviews', title: 'Reviews' });\n  });\n  router.post('/reviews/save', auth, body, async (req, res) => {\n    const b = req.body; const author=(b.author||'').trim(); const location=(b.location||'').trim();\n    const stars=Math.max(1,Math.min(5,parseInt(b.stars,10)||5)); const bodyText=(b.body||'').trim();\n    const approved=b.approved?true:false; const id=parseInt(b.id,10)||0;\n    if(!author||!bodyText) return res.redirect('/admin/reviews?ok=Author+and+review+are+required');\n    if(id) await pool.query('UPDATE reviews SET author=$1,location=$2,stars=$3,body=$4,approved=$5 WHERE id=$6',[author,location,stars,bodyText,approved,id]);\n    else await pool.query('INSERT INTO reviews(author,location,stars,body,approved) VALUES($1,$2,$3,$4,$5)',[author,location,stars,bodyText,approved]);\n    res.redirect('/admin/reviews?ok=Review+saved');\n  });\n  router.post('/reviews/:id/approve', auth, async (req, res) => { await pool.query('UPDATE reviews SET approved = NOT approved WHERE id=$1',[req.params.id]); res.redirect('/admin/reviews?ok=Updated'); });\n  router.post('/reviews/:id/delete', auth, async (req, res) => { await pool.query('DELETE FROM reviews WHERE id=$1',[req.params.id]); res.redirect('/admin/reviews?ok=Review+deleted'); });\n\n  return router;\n};" },
  { f:A+'/views/admin/_shell_top.ejs',
    a:"Marquee &amp; stats</a>",
    b:"Marquee &amp; stats</a>\n    <a href=\"/admin/reviews\" class=\"<%= on('reviews') %>\"><svg viewBox=\"0 0 24 24\"><path d=\"m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z\"/></svg>Reviews</a>" },
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
node --check "$APP/routes/adminCatalog.js"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");["views/admin/reviews.ejs","views/admin/_shell_top.ejs"].forEach(function(f){ejs.compile(fs.readFileSync("/opt/gsz/"+f,"utf8"),{filename:"/opt/gsz/"+f});console.log("   compiled "+f);});'
grep -q "/reviews/save" "$APP/routes/adminCatalog.js" || { echo "!! reviews routes missing"; false; }

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:3900/admin/reviews || true)
echo "   /admin/reviews -> HTTP $CODE"
[ "$CODE" = "302" ] || [ "$CODE" = "200" ] || { echo "!! reviews route error $CODE"; false; }
trap - ERR
echo "==> step67 OK — Reviews admin live. Backup: $BAK"
