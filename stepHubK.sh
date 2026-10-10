#!/usr/bin/env bash
# Galaxy Hub — Deploy K (field styling): theme password/email/tel/number inputs in the Hub modal
# (were unstyled native white boxes on Sign in / Create Account) and style the file-upload buttons
# in the Hub + checkout modals (were raw grey "Choose File"). Partials only, idempotent.
set -Eeuo pipefail
GSZ=/opt/gsz; TS=$(date +%s)
cd "$GSZ"
HM=views/partials/hub_model.ejs
CM=views/partials/checkout_model.ejs
cp -f "$HM" "$HM.bak.$TS"; cp -f "$CM" "$CM.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$HM.bak.$TS" "$HM"; cp -f "$CM.bak.$TS" "$CM"; }
trap restore ERR

node <<'JS'
const fs=require('fs');
function patch(file, oldStr, newStr, guard){
  let s=fs.readFileSync(file,'utf8');
  if(s.indexOf(guard)>=0){ console.log('  '+file+': already patched, skip'); return; }
  if(s.indexOf(oldStr)<0){ throw new Error('anchor not found in '+file); }
  fs.writeFileSync(file, s.replace(oldStr,newStr));
  console.log('  '+file+': patched');
}

patch('views/partials/hub_model.ejs',
  '.cthm input[type=text],.cthm input[type=file]{width:100%;background:#0e1627;border:1px solid rgba(255,255,255,.14);border-radius:11px;color:#eef2fb;padding:10px 12px;font-family:inherit;font-size:14px}',
  '.cthm input[type=text],.cthm input[type=email],.cthm input[type=password],.cthm input[type=tel],.cthm input[type=number],.cthm input[type=file]{width:100%;background:#0e1627;border:1px solid rgba(255,255,255,.14);border-radius:11px;color:#eef2fb;padding:10px 12px;font-family:inherit;font-size:14px}\n  .cthm input[type=file]{padding:6px}\n  .cthm input[type=file]::file-selector-button,.cthm input[type=file]::-webkit-file-upload-button{padding:8px 12px;margin-right:10px;border:0;border-radius:8px;background:#16203a;color:#eef2fb;font-family:inherit;font-size:13px;font-weight:700;cursor:pointer}',
  '.cthm input[type=password]');

patch('views/partials/checkout_model.ejs',
  '.gbuy input[type=text],.gbuy input[type=email],.gbuy input[type=file],.gbuy select{width:100%;background:#0e1627;border:1px solid var(--gb-ln);border-radius:11px;color:var(--gb-ink);padding:11px 13px;font-family:inherit;font-size:14px}',
  '.gbuy input[type=text],.gbuy input[type=email],.gbuy input[type=password],.gbuy input[type=tel],.gbuy input[type=number],.gbuy input[type=file],.gbuy select{width:100%;background:#0e1627;border:1px solid var(--gb-ln);border-radius:11px;color:var(--gb-ink);padding:11px 13px;font-family:inherit;font-size:14px}\n  .gbuy input[type=file]{padding:6px}\n  .gbuy input[type=file]::file-selector-button,.gbuy input[type=file]::-webkit-file-upload-button{padding:8px 12px;margin-right:10px;border:0;border-radius:8px;background:#16203a;color:var(--gb-ink);font-family:inherit;font-size:13px;font-weight:700;cursor:pointer}',
  '.gbuy input[type=password]');

// remove coupon placeholder hints (user: no hint in the coupon field) — global, idempotent
['views/partials/checkout_model.ejs','views/partials/hub_model.ejs'].forEach(function(f){
  let s=fs.readFileSync(f,'utf8'); const before=s;
  s=s.split(' placeholder="e.g. GALAXY10"').join('');
  if(s!==before){ fs.writeFileSync(f,s); console.log('  '+f+': coupon hint removed'); }
  else { console.log('  '+f+': coupon hint already gone'); }
});
JS

node -e "const ejs=require('ejs'),fs=require('fs');['$HM','$CM'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:process.cwd()+'/'+f});});console.log('  ejs ok');"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Deploy K: auth password/email fields themed; file-upload buttons styled (Hub + checkout)."
