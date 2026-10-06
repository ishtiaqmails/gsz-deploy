#!/usr/bin/env bash
# step52 — Mobile polish: remove product-count from hamburger categories, and make
# "Shop by category" a 2-column grid on phones (was a vertical list). + app.js cache bump.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step52-$TS
mkdir -p "$BAK/public/js" "$BAK/views/partials" "$BAK/views"
cp "$APP/public/js/app.js" "$BAK/public/js/app.js"
cp "$APP/views/partials/store_bottom.ejs" "$BAK/views/partials/store_bottom.ejs"
cp "$APP/views/home.ejs" "$BAK/views/home.ejs"
restore(){ echo "!! rollback";
  cp "$BAK/public/js/app.js" "$APP/public/js/app.js"
  cp "$BAK/views/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs"
  cp "$BAK/views/home.ejs" "$APP/views/home.ejs"
  pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> apply patches"
node <<'NODE'
const fs=require('fs');
const A='/opt/gsz';
const patches=[
  { file:A+'/public/js/app.js',
    find:"'<span><b>'+c.name+'</b><span class=\"n\">'+c.n+' product'+(c.n===1?'':'s')+'</span></span></a>';}).join('');",
    repl:"'<span><b>'+c.name+'</b></span></a>';}).join('');" },
  { file:A+'/views/partials/store_bottom.ejs',
    find:"/static/js/app.js?v=23",
    repl:"/static/js/app.js?v=24" },
  { file:A+'/views/home.ejs',
    find:"  #cats .cat-tile{justify-content:flex-start}",
    repl:"  #cats .cat-tile{justify-content:flex-start}\n  @media(max-width:560px){#cats .catgrid{grid-template-columns:repeat(2,1fr);justify-content:stretch}}" },
];
for(const p of patches){
  let s=fs.readFileSync(p.file,'utf8');
  if(s.indexOf(p.repl)>=0 && s.indexOf(p.find)<0){ console.log('   skip (already): '+p.file.split('/').pop()); continue; }
  if(s.indexOf(p.find)<0){ console.error('!! anchor missing in '+p.file); process.exit(2); }
  s=s.split(p.find).join(p.repl);
  fs.writeFileSync(p.file,s);
  console.log('   patched: '+p.file.split('/').pop());
}
NODE

echo "==> node --check app.js"; node --check "$APP/public/js/app.js"
echo "==> ejs compile"; node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");["views/home.ejs","views/partials/store_bottom.ejs"].forEach(function(f){ejs.compile(fs.readFileSync("/opt/gsz/"+f,"utf8"),{filename:"/opt/gsz/"+f});console.log("   compiled "+f);});'

echo "==> pm2 restart gsz"; pm2 restart gsz --update-env >/dev/null; sleep 3

echo "==> verify"
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
grep -q 'app.js?v=24' <<<"$H" || { echo "!! js version not bumped"; false; }
grep -q 'max-width:560px){#cats .catgrid' <<<"$H" || { echo "!! mobile catgrid rule missing"; false; }
JS=$(curl -s -m 10 "http://127.0.0.1:3900/static/js/app.js?v=24" || true)
grep -q "product'+(c.n" <<<"$JS" && { echo "!! drawer count still present"; false; } || true
grep -q 'dcat' <<<"$JS" || { echo "!! drawer builder missing"; false; }

trap - ERR
echo "==> step52 OK — hamburger count removed, category grid 2-col on phone. Backup: $BAK"
