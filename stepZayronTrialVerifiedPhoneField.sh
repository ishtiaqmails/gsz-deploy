#!/usr/bin/env bash
# stepZayronTrialVerifiedPhoneField — a VERIFIED customer must never be asked for a WhatsApp/phone again,
# even when the owner defined a phone-type trial field. So when verified:
#   - drop phone/WhatsApp-type owner fields from the form (the verified number covers them)
#   - base the one-tap auto-start on NON-phone required fields only (phone-only servers go straight through)
# All in public/ztrial.js. Safe: backup, single-match anchors + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp public/ztrial.js "$B/ztrial.js.bak"
revert(){ cp "$B/ztrial.js.bak" public/ztrial.js; pm2 restart zayron >/dev/null 2>&1 || true; }

node - <<'APPLY'
const fs=require('fs');const F='public/ztrial.js';let s=fs.readFileSync(F,'utf8');
function rep(o,n){const c=s.split(o).length-1;if(c!==1){console.error('ANCHOR x'+c+': '+o.slice(0,55));process.exit(5);}s=s.split(o).join(n);}

// A) one-tap decision ignores phone-type required fields (verified number covers them)
rep(
`      if (p) { _cameFromGrid = false; var _rf = (p.fields||[]).some(function(f){return f.required;}); if (VERIFIED && !_rf) return startDirect(p); return renderFields(p); }`,
`      if (p) { _cameFromGrid = false; var _rf = (p.fields||[]).some(function(f){return f.required && !(f.type==='phone' || /whats|phone|number|mobile/i.test(f.label||''));}); if (VERIFIED && !_rf) return startDirect(p); return renderFields(p); }`);

// B) verified: drop phone-type owner fields so no duplicate WhatsApp box
rep(
`  function renderFields(p) {
    var fields = p.fields || [];
    var fh = fields.map(function (fl, i) {`,
`  function renderFields(p) {
    var fields = p.fields || [];
    if (VERIFIED) { fields = fields.filter(function (fl) { return !(fl.type === 'phone' || /whats|phone|number|mobile/i.test(fl.label || '')); }); }
    var fh = fields.map(function (fl, i) {`);

fs.writeFileSync(F,s);console.log('ztrial.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; exit 1; }

node --check public/ztrial.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: verified users never see a WhatsApp field; phone-only servers go one-tap. healthz=200"
