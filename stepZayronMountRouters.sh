#!/usr/bin/env bash
# stepZayronMountRouters — the online store was disabled by two catch-all stubs that redirect
# /trial and /checkout to /contact. Replace them with the REAL routers (same pattern as /account),
# so the automated checkout + trial flows actually serve. The Manual-store guard (store_manual=1)
# still closes them to /contact when you want manual mode. Auto-reverts if the server won't boot.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp server.js "$B/server.js.bak"
revert(){ cp "$B/server.js.bak" server.js; pm2 restart zayron >/dev/null 2>&1 || true; }

node - <<'APPLY'
const fs = require('fs'); const F = 'server.js';
let s = fs.readFileSync(F, 'utf8');
function rep(o, n){ const c = s.split(o).length - 1; if (c !== 1){ console.error('ANCHOR x'+c+': '+o.slice(0,60)); process.exit(5);} s = s.split(o).join(n); }
rep(
  "app.use('/trial', function (req, res) { res.redirect(302, '/contact'); });",
  "app.use('/trial', require('./routes/trial')({ pool, getPublicData, isTrialDisabled, shellPage, escAttr }));"
);
rep(
  "app.use('/checkout', function (req, res) { res.redirect(302, '/contact'); });",
  "app.use('/checkout', require('./routes/checkout')({ pool, shellPage, escAttr, getPublicData }));"
);
fs.writeFileSync(F, s);
console.log('server.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed"; exit 1; }

node --check server.js || { echo "syntax error - reverting"; revert; exit 1; }

pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
sleep 3
HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz || echo 000)
if [ "$HC" != "200" ]; then echo "healthz=$HC — server not healthy, REVERTING"; revert; sleep 2; echo "reverted."; exit 1; fi
echo "healthz=200 (server up)"
echo "--- /trial/providers now ---"
curl -s "http://127.0.0.1:3500/trial/providers" | node -e "let b='';process.stdin.on('data',d=>b+=d);process.stdin.on('end',()=>{try{const j=JSON.parse(b);console.log('ok:',j.ok,'| master_off:',j.master_off,'| providers:',(j.providers||[]).length,'|',(j.providers||[]).map(p=>p.slug).join(', '))}catch(e){console.log('RAW:',b.slice(0,160))}})"
echo "--- /checkout (should be 200 or login redirect, NOT /contact) ---"
curl -s -o /dev/null -w "checkout: %{http_code} %{redirect_url}\n" "http://127.0.0.1:3500/checkout"
echo "DONE: real /trial + /checkout routers mounted. Online store is reachable."
