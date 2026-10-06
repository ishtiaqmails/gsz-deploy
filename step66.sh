#!/usr/bin/env bash
# step66 — Content admin: editable marquee + homepage numbers (rating, delivered
# floor, since, reviews count). Marquee flows to the site via shellJson + app.js.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step66-$TS
mkdir -p "$BAK/routes" "$BAK/lib" "$BAK/public/js" "$BAK/views/admin" "$BAK/views/partials"
cp "$APP/routes/admin.js" "$BAK/routes/admin.js"
cp "$APP/lib/storefront.js" "$BAK/lib/storefront.js"
cp "$APP/public/js/app.js" "$BAK/public/js/app.js"
cp "$APP/views/admin/_shell_top.ejs" "$BAK/views/admin/_shell_top.ejs"
cp "$APP/views/partials/store_bottom.ejs" "$BAK/views/partials/store_bottom.ejs"
restore(){ echo "!! rollback";
  cp "$BAK/routes/admin.js" "$APP/routes/admin.js"
  cp "$BAK/lib/storefront.js" "$APP/lib/storefront.js"
  cp "$BAK/public/js/app.js" "$APP/public/js/app.js"
  cp "$BAK/views/admin/_shell_top.ejs" "$APP/views/admin/_shell_top.ejs"
  cp "$BAK/views/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs"
  rm -f "$APP/views/admin/content.ejs"
  pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR
writef(){ local dest="$APP/$1" b64="$2" md5="$3"; base64 -d "$b64" > "$dest"; local got; got=$(md5sum "$dest"|awk '{print $1}'); echo "   $1 $got $([ "$got" = "$md5" ] && echo OK || echo MISMATCH)"; [ "$got" = "$md5" ] || { echo "!! md5 mismatch $1"; false; }; }
cat > /tmp/s66_content.b64 <<'B66_content'
PCUtIGluY2x1ZGUoJ19zaGVsbF90b3AnLCB7IGFjdGl2ZTonY29udGVudCcsIHRpdGxlOidDb250ZW50JyB9KSAlPgo8cCBjbGFzcz0ic3ViIiBzdHlsZT0ibWFyZ2luLWJvdHRvbToxOHB4Ij5FZGl0IHRoZSBzY3JvbGxpbmcgbWFycXVlZSBzdHJpcCBhbmQgdGhlIGhvbWVwYWdlIHRydXN0IG51bWJlcnMuPC9wPgo8JSBpZiAoZmxhc2gpIHsgJT48ZGl2IGNsYXNzPSJmbGFzaCI+PCU9IGZsYXNoICU+PC9kaXY+PCUgfSAlPgo8Zm9ybSBtZXRob2Q9InBvc3QiIGFjdGlvbj0iL2FkbWluL2NvbnRlbnQvc2F2ZSI+CiAgPGRpdiBjbGFzcz0iY2FyZCI+CiAgICA8aDI+SG9tZXBhZ2UgbnVtYmVyczwvaDI+CiAgICA8cCBjbGFzcz0iaGludCI+U2hvd24gaW4gdGhlIHN0YXRzIGJhbmQgYW5kIHRoZSByZXZpZXdzIGJsb2NrLiAiT3JkZXJzIGRlbGl2ZXJlZCIgbmV2ZXIgZHJvcHMgYmVsb3cgNTAsMDAwLjwvcD4KICAgIDxsYWJlbCBjbGFzcz0iZmxkIj5BdmVyYWdlIHJhdGluZyAoZS5nLiA0LjkpPC9sYWJlbD4KICAgIDxpbnB1dCB0eXBlPSJ0ZXh0IiBuYW1lPSJyYXRpbmciIHZhbHVlPSI8JT0gc2V0dGluZ3MucmF0aW5nIHx8ICcnICU+IiBwbGFjZWhvbGRlcj0iNC45Ij4KICAgIDxsYWJlbCBjbGFzcz0iZmxkIj5PcmRlcnMgZGVsaXZlcmVkIGZsb29yIChlLmcuIDUwLDAwMCspPC9sYWJlbD4KICAgIDxpbnB1dCB0eXBlPSJ0ZXh0IiBuYW1lPSJkZWxpdmVyZWQiIHZhbHVlPSI8JT0gc2V0dGluZ3MuZGVsaXZlcmVkIHx8ICcnICU+IiBwbGFjZWhvbGRlcj0iNTAsMDAwKyI+CiAgICA8bGFiZWwgY2xhc3M9ImZsZCI+U2luY2UgeWVhciAoZS5nLiAyMDIxKTwvbGFiZWw+CiAgICA8aW5wdXQgdHlwZT0idGV4dCIgbmFtZT0ic2luY2UiIHZhbHVlPSI8JT0gc2V0dGluZ3Muc2luY2UgfHwgJycgJT4iIHBsYWNlaG9sZGVyPSIyMDIxIj4KICAgIDxsYWJlbCBjbGFzcz0iZmxkIj5SZXZpZXdzIGNvdW50IChlLmcuIDEsMjg0KTwvbGFiZWw+CiAgICA8aW5wdXQgdHlwZT0idGV4dCIgbmFtZT0icmV2aWV3c19jb3VudCIgdmFsdWU9IjwlPSBzZXR0aW5ncy5yZXZpZXdzX2NvdW50IHx8ICcnICU+IiBwbGFjZWhvbGRlcj0iMSwyODQiPgogIDwvZGl2PgogIDxkaXYgY2xhc3M9ImNhcmQiPgogICAgPGgyPk1hcnF1ZWUgc3RyaXA8L2gyPgogICAgPHAgY2xhc3M9ImhpbnQiPk9uZSBtZXNzYWdlIHBlciBsaW5lIOKAlCB0aGVzZSBzY3JvbGwgYWNyb3NzIHRoZSB0b3AgYmFyIG9mIHRoZSBzaXRlLjwvcD4KICAgIDx0ZXh0YXJlYSBuYW1lPSJtYXJxdWVlIiByb3dzPSI4IiBwbGFjZWhvbGRlcj0iSW5zdGFudCBhdXRvbWF0ZWQgZGVsaXZlcnkKUmVhbCBXaGF0c0FwcCBzdXBwb3J0ClZlcmlmaWVkIGJlZm9yZSB3ZSBkZWxpdmVyIj48JT0gc2V0dGluZ3MubWFycXVlZSB8fCAnJyAlPjwvdGV4dGFyZWE+CiAgPC9kaXY+CiAgPGRpdiBzdHlsZT0iZGlzcGxheTpmbGV4O2dhcDoxMHB4Ij48YnV0dG9uIGNsYXNzPSJidG4gYnRuLXAiIHR5cGU9InN1Ym1pdCI+U2F2ZSBjb250ZW50PC9idXR0b24+PGEgY2xhc3M9ImJ0biBidG4tZyIgaHJlZj0iL2FkbWluL2NvbnRlbnQiPlJlc2V0PC9hPjwvZGl2Pgo8L2Zvcm0+CjwlLSBpbmNsdWRlKCdfc2hlbGxfYm90dG9tJykgJT4K
B66_content
writef "views/admin/content.ejs" /tmp/s66_content.b64 "bf67e2b3678b7a2c3c8a20a2d6dd7c17"
rm -f /tmp/s66_content.b64

echo "==> patch routes/nav/shellJson/app.js"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const P=[
  // admin.js: add content routes before return router
  { f:A+'/routes/admin.js',
    a:"  return router;\n};",
    b:"  router.get('/content', auth, async (req, res) => {\n    const settings = {}; (await pool.query('SELECT key,value FROM settings')).rows.forEach(r => { settings[r.key] = r.value; });\n    res.render('admin/content', { settings, flash: req.query.ok || null, active: 'content', title: 'Content' });\n  });\n  router.post('/content/save', auth, express.urlencoded({ extended: true }), async (req, res) => {\n    const b = req.body || {};\n    for (const k of ['rating','delivered','since','reviews_count','marquee']) {\n      const val = (b[k] != null ? String(b[k]) : '').trim();\n      await pool.query('INSERT INTO settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value', [k, val]);\n    }\n    res.redirect('/admin/content?ok=Content+saved');\n  });\n\n  return router;\n};" },
  // nav: add Content link after Branding
  { f:A+'/views/admin/_shell_top.ejs',
    a:"Branding &amp; Banners</a>",
    b:"Branding &amp; Banners</a>\n    <a href=\"/admin/content\" class=\"<%= on('content') %>\"><svg viewBox=\"0 0 24 24\"><path d=\"M4 6h16M4 12h16M4 18h10\"/></svg>Marquee &amp; stats</a>" },
  // storefront shellJson: include marquee
  { f:A+'/lib/storefront.js',
    a:"settings:{ rating:settings.rating, delivered:settings.delivered }, wa:wa||'' }",
    b:"settings:{ rating:settings.rating, delivered:settings.delivered }, marquee:settings.marquee||'', wa:wa||'' }" },
  // app.js buildMarquee: use editable marquee
  { f:A+'/public/js/app.js',
    a:"  var items=['Instant automated delivery','Pay in PKR, USD or crypto','Verified before we deliver','Real WhatsApp support','Free IPTV trial available','Thousands of live channels & VOD','Works on every device','Trusted since 2021'];",
    b:"  var items=(D.marquee||'').split('\\n').map(function(s){return s.trim();}).filter(Boolean);\n  if(!items.length) items=['Instant automated delivery','Pay in PKR, USD or crypto','Verified before we deliver','Real WhatsApp support','Free IPTV trial available','Thousands of live channels & VOD','Works on every device','Trusted since 2021'];" },
  // cache bump app.js
  { f:A+'/views/partials/store_bottom.ejs',
    a:"/static/js/app.js?v=24",
    b:"/static/js/app.js?v=25" },
];
for(const p of P){
  let s=fs.readFileSync(p.f,'utf8');
  if(s.indexOf(p.b)>=0 && s.indexOf(p.a)<0){ console.log('   skip: '+p.f.split('/').pop()); continue; }
  if(s.indexOf(p.a)<0){ console.error('!! anchor missing in '+p.f+' :: '+p.a.slice(0,42)); process.exit(2); }
  s=s.split(p.a).join(p.b); fs.writeFileSync(p.f,s);
  console.log('   patched: '+p.f.split('/').pop());
}
NODE

echo "==> node --check + ejs compile"
node --check "$APP/routes/admin.js"
node --check "$APP/lib/storefront.js"
node --check "$APP/public/js/app.js"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");["views/admin/content.ejs","views/admin/_shell_top.ejs","views/partials/store_bottom.ejs"].forEach(function(f){ejs.compile(fs.readFileSync("/opt/gsz/"+f,"utf8"),{filename:"/opt/gsz/"+f});console.log("   compiled "+f);});'

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
grep -q 'app.js?v=25' <<<"$H" || { echo "!! app.js cache not bumped"; false; }
grep -q 'max-width:560px){#cats .catgrid' <<<"$H" || { echo "!! step52 rule lost"; false; }
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:3900/admin/content || true)
echo "   /admin/content -> HTTP $CODE"
[ "$CODE" = "302" ] || [ "$CODE" = "200" ] || { echo "!! content route error $CODE"; false; }
JS=$(curl -s -m 10 "http://127.0.0.1:3900/static/js/app.js?v=25" || true)
grep -q 'D.marquee' <<<"$JS" || { echo "!! marquee wiring missing in app.js"; false; }
trap - ERR
echo "==> step66 OK — Content admin (marquee + numbers) live. Backup: $BAK"
