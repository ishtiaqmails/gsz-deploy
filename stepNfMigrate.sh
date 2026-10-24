#!/usr/bin/env bash
# stepNfMigrate.sh — migrate the website's portal integration to the NEW gzportal API.
#   Deploys lib/nfPortal.js, lib/nfMail.js, lib/netflixGate.js, routes/adminNetflix.js (full),
#   patches lib/deliver.js (full-account delivery text). Repoints auth to Authorization: Bearer.
#   First run: pass the key ->  NF_KEY='gzp_...' bash stepNfMigrate.sh   (writes .env; not committed).
#   Idempotent; restores on failure. Read-only self-test at the end.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-nfmig-$TS"; cd "$GSZ"
FILES="lib/nfPortal.js lib/nfMail.js lib/netflixGate.js routes/adminNetflix.js lib/deliver.js .env"
mkdir -p "$BK/lib" "$BK/routes"
for f in $FILES; do [ -f "$GSZ/$f" ] && cp "$GSZ/$f" "$BK/$f" || true; done
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in $FILES; do [ -f "$BK/$f" ] && cp "$BK/$f" "$GSZ/$f" || true; done; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

set_env(){ local k="$1" v="$2"; if grep -q "^$k=" "$GSZ/.env"; then sed -i "s|^$k=.*|$k=$v|" "$GSZ/.env"; else printf '%s=%s\n' "$k" "$v" >> "$GSZ/.env"; fi; }
if [ -n "${NF_KEY:-}" ]; then
  set_env NF_PORTAL_URL "https://app.galaxyzayron.store/api/v1"
  set_env NF_READ_KEY "$NF_KEY"
  echo "   .env updated: NF_PORTAL_URL + NF_READ_KEY (Bearer)"
else
  echo "   NF_KEY not passed — using existing .env (must already have the new base + key)"
fi

echo "==> deploy new portal clients + admin + patch deliver"
cp -f "$SRC/nfPortal.js"     "$GSZ/lib/nfPortal.js"
cp -f "$SRC/nfMail.js"       "$GSZ/lib/nfMail.js"
cp -f "$SRC/netflixGate.js"  "$GSZ/lib/netflixGate.js"
cp -f "$SRC/adminNetflix.js" "$GSZ/routes/adminNetflix.js"
node "$SRC/patch_nfdeliver.js" "$GSZ"

echo "==> validate"
for f in lib/nfPortal.js lib/nfMail.js lib/netflixGate.js routes/adminNetflix.js lib/deliver.js; do node --check "$GSZ/$f" && echo "   $f ok"; done

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "   health OK (${i}s)"; break; }; sleep 1; done

echo "==> read-only self-test (new API, via deployed libs)"
node - "$GSZ" <<'NODE' || echo "   (self-test error — non-fatal; check .env key)"
const R=process.argv[2];
require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const nfPortal=require(R+'/lib/nfPortal'), nfMail=require(R+'/lib/nfMail');
const https=require('https'),{URL}=require('url');
const BASE=(process.env.NF_PORTAL_URL||'').replace(/\/+$/,''),KEY=process.env.NF_READ_KEY||'';
function g(p){return new Promise(r=>{try{const u=new URL(BASE+p);const q=https.request({hostname:u.hostname,port:443,path:u.pathname+u.search,method:'GET',headers:{Authorization:'Bearer '+KEY,Accept:'application/json'}},res=>{let b='';res.on('data',d=>b+=d);res.on('end',()=>{let j=null;try{j=JSON.parse(b);}catch(e){}r(j);});});q.on('error',()=>r(null));q.setTimeout(10000,()=>q.destroy());q.end();}catch(e){r(null);}});}
(async()=>{
  console.log('   configured:',nfPortal.configured());
  const p=await nfPortal.products(); console.log('   products: '+p.length+' -> '+p.slice(0,3).map(x=>x.name+' (old_id '+x.old_id+', free '+x.free+')').join(' | '));
  const s=await nfPortal.stock(1); console.log('   stock(old_id 1): '+JSON.stringify(s));
  const st=await g('/stock?product=1'); const em=st&&st.accounts&&st.accounts[0]&&st.accounts[0].email;
  if(em){ const m=await nfMail.listForAccount(em,true); const e0=(m.emails||[])[0]; console.log('   codes('+em+'): ok='+m.ok+' count='+(m.emails||[]).length+(e0?(' sample={type:'+e0.type+', link:'+(e0.link?'ok':'none')+', date:'+(e0.date||'')+'}'):'')); }
  else console.log('   (no free account to sample codes — ok)');
})().catch(e=>console.error('   selftest err',e.message));
NODE
echo "DONE — read path migrated (products/stock/codes via new Bearer API), assign + delivery text updated. Household 'Get Access' button = small Phase 2 follow-up."
