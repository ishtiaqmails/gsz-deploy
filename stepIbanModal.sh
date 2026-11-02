#!/usr/bin/env bash
# stepIbanModal.sh — show the extra field (IBAN) in the quick-buy modal + hub buy flows.
# 1) /account/tools/pay-methods now returns extra_label/extra_value per method.
# 2) the modal acct() render appends "<label>: <value>" under the account (display only).
# Bot + verification untouched; data comes from the existing payment_logos row.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
FILES="routes/checkout.js views/partials/checkout_model.ejs views/partials/hub_model.ejs"
for f in $FILES; do cp -f "$f" "$f.xbak.$TS"; done
restore(){ echo "!! failed — rolling back"; for f in $FILES; do cp -f "$f.xbak.$TS" "$f"; done; rm -f .gszm_p.js .gszm_v.js; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> patching endpoint + modal renders"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
function patchFile(file, pairs, guard, guardMsg) {
  let s = fs.readFileSync(file, 'utf8');
  if (guard && s.indexOf(guard) >= 0) { console.log('  ' + file + ': already patched (' + guardMsg + ')'); return; }
  pairs.forEach(function (p) {
    const n = s.split(p.a).length - 1;
    if (p.exact != null && n !== p.exact) throw new Error(file + ': anchor x' + n + ' (need ' + p.exact + '): ' + p.a.slice(0, 48));
    if (p.min != null && n < p.min) throw new Error(file + ': anchor x' + n + ' (need >=' + p.min + '): ' + p.a.slice(0, 48));
    s = s.split(p.a).join(p.b);
    console.log('  ' + file + ': replaced ' + n);
  });
  fs.writeFileSync(file, s);
}

// 1) endpoint — add extra fields to the pay-methods JSON shape
patchFile('routes/checkout.js', [{
  a: "instructions:m.instructions||'', currency:m.currency||'', botAcct:!!m.botAcct }",
  b: "instructions:m.instructions||'', currency:m.currency||'', extra_label:m.extra_label||'', extra_value:m.extra_value||'', botAcct:!!m.botAcct }",
  exact: 1
}], 'extra_value:m.extra_value', 'endpoint');

// 2) modal/hub render — append the extra line to `lines` before the pre is built
var RA = 'var cpVal=m.account||lines;';
var RB = "if(m.extra_value){lines+=String.fromCharCode(10)+(m.extra_label||'IBAN')+': '+m.extra_value;} var cpVal=m.account||lines;";
patchFile('views/partials/checkout_model.ejs', [{ a: RA, b: RB, min: 1 }], "(m.extra_label||'IBAN')", 'checkout_model render');
patchFile('views/partials/hub_model.ejs',      [{ a: RA, b: RB, min: 1 }], "(m.extra_label||'IBAN')", 'hub_model render');
JS
node .gszm_p.js

echo "==> validating"
node --check routes/checkout.js
cat > .gszm_v.js <<'JS'
const ejs = require('ejs'), fs = require('fs');
['views/partials/checkout_model.ejs','views/partials/hub_model.ejs'].forEach(function(f){ ejs.compile(fs.readFileSync(f,'utf8'),{filename:f}); console.log('  compiles: '+f); });
JS
node .gszm_v.js
rm -f .gszm_p.js .gszm_v.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — IBAN now shows in the quick-buy modal under the account (select Meezan)."
