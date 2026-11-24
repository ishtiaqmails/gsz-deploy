#!/usr/bin/env bash
# diagFindRealCustomers — the LIVE /admin/customers page is richer than admin.js's routes, so it is
# served from another file mounted before admin.js. Locate that file + its customer SAVE handler, and
# show how /admin is mounted. Read-only.
set -e
cd /opt/zayron
echo "### files containing the live page's distinctive strings ###"
grep -rln "masked by a VPN\|Edit details\|today with us" --include=*.js --include=*.ejs . 2>/dev/null | grep -v node_modules || true
echo
echo "### route files that define a customers route ###"
grep -rln "'/customers\|\"/customers\|/customers/:id\|customers/:id" routes 2>/dev/null | grep -v node_modules || true
echo
echo "### how /admin (and any admin sub-router) is mounted in server.js ###"
grep -n "admin\|/customers" server.js 2>/dev/null | head -40 || true
echo
echo "### the customer SAVE/update handler (post to a customer) across routes ###"
node - <<'NODE'
const fs=require('fs'),path=require('path');
const dir='routes';
for(const f of fs.readdirSync(dir)){
  if(!f.endsWith('.js')) continue;
  const p=path.join(dir,f);
  const s=fs.readFileSync(p,'utf8').split('\n');
  for(let i=0;i<s.length;i++){
    if(/router\.(post|put|patch)\(\s*['"][^'"]*customers\/:?id?['"/:]/.test(s[i]) || /router\.(post|put|patch)\(\s*['"][^'"]*\/customers/.test(s[i])){
      console.log('=== '+p+' line '+(i+1)+' ===');
      for(let j=i;j<Math.min(i+55,s.length);j++) console.log((j+1)+': '+s[j]);
      console.log();
    }
  }
}
NODE
echo DONE
