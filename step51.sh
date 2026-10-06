#!/usr/bin/env bash
# step51 — Mobile fixes (#6): lock body scroll when the hamburger menu is open,
# make the menu panel scroll internally, and bump asset cache versions so phones
# load the new files.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step51-$TS
mkdir -p "$BAK/public/js" "$BAK/public/css" "$BAK/views/partials"
cp "$APP/public/js/app.js" "$BAK/public/js/app.js"
cp "$APP/public/css/app.css" "$BAK/public/css/app.css"
cp "$APP/views/partials/store_top.ejs" "$BAK/views/partials/store_top.ejs"
cp "$APP/views/partials/store_bottom.ejs" "$BAK/views/partials/store_bottom.ejs"
restore(){ echo "!! rollback";
  cp "$BAK/public/js/app.js" "$APP/public/js/app.js"
  cp "$BAK/public/css/app.css" "$APP/public/css/app.css"
  cp "$BAK/views/partials/store_top.ejs" "$APP/views/partials/store_top.ejs"
  cp "$BAK/views/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs"
  pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> apply patches"
node <<'NODE'
const fs=require('fs');
const A='/opt/gsz';
const patches=[
  { file:A+'/public/js/app.js',
    find:"function openDrawer(){$('#drawer').classList.add('on');$('#scrim').classList.add('on');}",
    repl:"function openDrawer(){$('#drawer').classList.add('on');$('#scrim').classList.add('on');try{document.body.style.overflow='hidden';}catch(e){}}" },
  { file:A+'/public/js/app.js',
    find:"function closeDrawer(){$('#drawer').classList.remove('on');$('#scrim').classList.remove('on');}",
    repl:"function closeDrawer(){$('#drawer').classList.remove('on');$('#scrim').classList.remove('on');try{document.body.style.overflow='';}catch(e){}}" },
  { file:A+'/public/css/app.css',
    find:"transition:transform .28s ease;display:flex;flex-direction:column;padding:18px}",
    repl:"transition:transform .28s ease;display:flex;flex-direction:column;padding:18px;overflow-y:auto;overscroll-behavior:contain;-webkit-overflow-scrolling:touch}" },
  { file:A+'/views/partials/store_top.ejs',
    find:"/static/css/app.css?v=21",
    repl:"/static/css/app.css?v=22" },
  { file:A+'/views/partials/store_bottom.ejs',
    find:"/static/js/app.js?v=22",
    repl:"/static/js/app.js?v=23" },
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

echo "==> node --check app.js"
node --check "$APP/public/js/app.js"
echo "==> ejs compile partials"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");["views/partials/store_top.ejs","views/partials/store_bottom.ejs"].forEach(function(f){ejs.compile(fs.readFileSync("/opt/gsz/"+f,"utf8"),{filename:"/opt/gsz/"+f});console.log("   compiled "+f);});'

echo "==> pm2 restart gsz"; pm2 restart gsz --update-env >/dev/null; sleep 3

echo "==> verify"
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
grep -q 'app.css?v=22' <<<"$H" || { echo "!! css version not bumped in output"; false; }
grep -q 'app.js?v=23'  <<<"$H" || { echo "!! js version not bumped in output"; false; }
CSS=$(curl -s -m 10 "http://127.0.0.1:3900/static/css/app.css?v=22" || true)
grep -q 'overscroll-behavior:contain' <<<"$CSS" || { echo "!! drawer overflow rule missing"; false; }
JS=$(curl -s -m 10 "http://127.0.0.1:3900/static/js/app.js?v=23" || true)
grep -q "body.style.overflow='hidden'" <<<"$JS" || { echo "!! body lock missing in app.js"; false; }

trap - ERR
echo "==> step51 OK — mobile drawer/scroll fixed. Backup: $BAK"
