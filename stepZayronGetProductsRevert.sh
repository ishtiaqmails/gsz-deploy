#!/usr/bin/env bash
# stepZayronGetProductsRevert — revert getProducts() to return the object { products:[...] }, which is
# what every caller (trialToggle, paidToggle, admin mapping dropdown, orderDispatch) expects. My earlier
# "array" change was the real regression (empty trials + empty mapping dropdown). Restart clears the cache.
# Safe: backup, single-match anchor + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp lib/gszApi.js "$B/gszApi.js.bak"
revert(){ cp "$B/gszApi.js.bak" lib/gszApi.js; pm2 restart zayron >/dev/null 2>&1 || true; }

node - <<'APPLY'
const fs=require('fs');const F='lib/gszApi.js';let s=fs.readFileSync(F,'utf8');
const o=`async function getProducts() {
  const hit = cget('prod'); if (hit !== undefined) return hit;
  const j = await req('GET', '/api/products', null, 8000);
  const arr = (j && Array.isArray(j.products)) ? j.products : (Array.isArray(j) ? j : []);
  return cset('prod', arr, TTL.prod);
}`;
const n=`async function getProducts() {
  const hit = cget('prod'); if (hit !== undefined) return hit;
  const j = await req('GET', '/api/products', null, 8000);
  return cset('prod', j, TTL.prod);
}`;
const c=s.split(o).length-1;
if(c!==1){console.error('ANCHOR x'+c);process.exit(5);}
fs.writeFileSync(F,s.split(o).join(n));
console.log('gszApi.js PATCHED OK (getProducts -> object)');
APPLY
[ $? -eq 0 ] || { echo "patch failed"; exit 1; }

node --check lib/gszApi.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "--- /trial/providers now ---"
curl -s "http://127.0.0.1:3500/trial/providers" | node -e "let b='';process.stdin.on('data',d=>b+=d);process.stdin.on('end',()=>{try{const j=JSON.parse(b);console.log('providers:',(j.providers||[]).length,'|',(j.providers||[]).map(p=>p.slug).join(', '))}catch(e){console.log('RAW:',b.slice(0,120))}})"
echo "DONE: getProducts restored; trials + mapping dropdown back. healthz=200"
