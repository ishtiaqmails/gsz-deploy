#!/usr/bin/env bash
# diagCustomersSave — print the existing admin Customers routes (list, manage, and the edit-details
# SAVE handler) so we can see whether changing the WhatsApp number forces re-verify. Read-only.
set -e
cd /opt/zayron
echo "### occurrences of /customers in routes/admin.js ###"
grep -n "/customers" routes/admin.js || true
echo
echo "### each router.*('/customers... block (handler head) ###"
node - <<'NODE'
const fs=require('fs');
const s=fs.readFileSync('routes/admin.js','utf8').split('\n');
for(let i=0;i<s.length;i++){
  if(/router\.(get|post|put|patch|delete)\(\s*['"][^'"]*\/customers/.test(s[i])){
    console.log('--- line '+(i+1)+' ---');
    for(let j=i;j<Math.min(i+60,s.length);j++){ console.log((j+1)+': '+s[j]); }
    console.log();
  }
}
NODE
echo "### does the save touch phone_verified / otp_outbox? ###"
grep -n "phone_verified\|otp_outbox\|otp_code" routes/admin.js | head -40 || true
echo DONE
