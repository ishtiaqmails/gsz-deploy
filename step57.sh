#!/usr/bin/env bash
# step57 — Revert the product-card name background panel (step55) back to the clean title.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step57-$TS
mkdir -p "$BAK/public/css" "$BAK/views/partials"
cp "$APP/public/css/app.css" "$BAK/public/css/app.css"
cp "$APP/views/partials/store_top.ejs" "$BAK/views/partials/store_top.ejs"
restore(){ echo "!! rollback"; cp "$BAK/public/css/app.css" "$APP/public/css/app.css"; cp "$BAK/views/partials/store_top.ejs" "$APP/views/partials/store_top.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> revert .pname + bump css version"
node <<'NODE'
const fs=require('fs');
const A='/opt/gsz';
const patches=[
  { file:A+'/public/css/app.css',
    find:".pcard .pname{font-family:var(--display);font-weight:700;font-size:16px;letter-spacing:-.01em;line-height:1.2;background:linear-gradient(180deg,rgba(255,255,255,.07),rgba(255,255,255,.02));border:1px solid var(--line);border-radius:10px;padding:8px 11px;color:var(--ink)}/*namebg*/",
    repl:".pcard .pname{font-family:var(--display);font-weight:700;font-size:16px;letter-spacing:-.01em;line-height:1.2}" },
  { file:A+'/views/partials/store_top.ejs',
    find:"/static/css/app.css?v=23",
    repl:"/static/css/app.css?v=24" },
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

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
grep -q 'app.css?v=24' <<<"$H" || { echo "!! css version not bumped"; false; }
CSS=$(curl -s -m 10 "http://127.0.0.1:3900/static/css/app.css?v=24" || true)
grep -q 'namebg' <<<"$CSS" && { echo "!! name panel still present"; false; } || true
trap - ERR
echo "==> step57 OK — product-card name reverted to clean title. Backup: $BAK"
