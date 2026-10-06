#!/usr/bin/env bash
# step55 — Product-card name background: subtle rounded panel behind each product
# title on the cards. + app.css cache bump.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step55-$TS
mkdir -p "$BAK/public/css" "$BAK/views/partials"
cp "$APP/public/css/app.css" "$BAK/public/css/app.css"
cp "$APP/views/partials/store_top.ejs" "$BAK/views/partials/store_top.ejs"
restore(){ echo "!! rollback"; cp "$BAK/public/css/app.css" "$APP/public/css/app.css"; cp "$BAK/views/partials/store_top.ejs" "$APP/views/partials/store_top.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> apply patches"
node <<'NODE'
const fs=require('fs');
const A='/opt/gsz';
const patches=[
  { file:A+'/public/css/app.css',
    find:".pcard .pname{font-family:var(--display);font-weight:700;font-size:16px;letter-spacing:-.01em;line-height:1.2}",
    repl:".pcard .pname{font-family:var(--display);font-weight:700;font-size:16px;letter-spacing:-.01em;line-height:1.2;background:linear-gradient(180deg,rgba(255,255,255,.07),rgba(255,255,255,.02));border:1px solid var(--line);border-radius:10px;padding:8px 11px;color:var(--ink)}/*namebg*/" },
  { file:A+'/views/partials/store_top.ejs',
    find:"/static/css/app.css?v=22",
    repl:"/static/css/app.css?v=23" },
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

echo "==> ejs compile store_top"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("/opt/gsz/views/partials/store_top.ejs","utf8"),{filename:"/opt/gsz/views/partials/store_top.ejs"});console.log("   OK");'

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
grep -q 'app.css?v=23' <<<"$H" || { echo "!! css version not bumped"; false; }
CSS=$(curl -s -m 10 "http://127.0.0.1:3900/static/css/app.css?v=23" || true)
grep -q 'namebg' <<<"$CSS" || { echo "!! name-bg rule missing"; false; }
trap - ERR
echo "==> step55 OK — product-card name background live. Backup: $BAK"
