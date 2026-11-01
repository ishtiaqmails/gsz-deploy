#!/usr/bin/env bash
# stepTrialNeeds.sh — make trial generation honor each product's declared `needs` (plan_key/type)
# from the synced bot catalog, so variant products (Mega OTT, and any future one) can generate a
# trial. Deploys lib/trialspec.js and wires it into both the trial route and the poller re-request.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TR="$GSZ/routes/trials.js"; TP="$GSZ/lib/trialpoll.js"; TS2="$GSZ/lib/trialspec.js"; TS=$(date +%s)
for f in "$TR" "$TP"; do [ -f "$f" ] || { echo "missing: $f"; exit 1; }; done
cp -f "$TR" "$TR.xbak.$TS"; cp -f "$TP" "$TP.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$TR.xbak.$TS" "$TR"; cp -f "$TP.xbak.$TS" "$TP"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> deploy lib/trialspec.js"
cp -f "$DEPLOY/lib/trialspec.js" "$TS2"; node --check "$TS2"

echo "==> patch routes/trials.js + lib/trialpoll.js"
export TR TP
node <<'NODE'
const fs=require('fs');
function patch(file, oldExpr, newExpr){
  let s=fs.readFileSync(file,'utf8');
  if(s.indexOf('trialspec')>=0){ console.log('   '+file+': already patched'); return; }
  if(s.split(oldExpr).length-1!==1) throw new Error(file+': anchor not unique ('+(s.split(oldExpr).length-1)+')');
  s=s.split(oldExpr).join(newExpr); fs.writeFileSync(file,s); console.log('   '+file+': wired to trialspec');
}
patch(process.env.TR,
  "botapi.generateTrial({ sku, hours: srv.duration_hours, customer_ref: v.ref, request_id: ref })",
  "botapi.generateTrial(Object.assign({ sku, hours: srv.duration_hours, customer_ref: v.ref, request_id: ref }, await require('../lib/trialspec').trialExtras(pool, sku)))");
patch(process.env.TP,
  "botapi.generateTrial({ sku: t.trial_type, hours: t.duration_hours || 24, customer_ref: t.ref_code || '', request_id: t.bot_ref })",
  "botapi.generateTrial(Object.assign({ sku: t.trial_type, hours: t.duration_hours || 24, customer_ref: t.ref_code || '', request_id: t.bot_ref }, await require('./trialspec').trialExtras(pool, t.trial_type)))");
NODE

echo "==> checks"
node --check "$TR"; node --check "$TP"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — trials now send plan_key/type for products that declare needing them. Backups: *.xbak.$TS"
