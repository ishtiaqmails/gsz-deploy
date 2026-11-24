#!/usr/bin/env bash
# diagCustomerAdminFile — dump the real customer-admin router's routes + SAVE handler and whether it
# re-verifies on number change. Read-only.
set -e
cd /opt/zayron
echo "### how lib/customerAdmin.js is wired into admin.js ###"
grep -n "customerAdmin" routes/admin.js || true
echo
echo "### route declarations in lib/customerAdmin.js ###"
grep -n "router\.\(get\|post\|put\|patch\|delete\)\|module.exports\|function mount\|express.Router\|urlencoded" lib/customerAdmin.js || true
echo
echo "### verification-related lines in lib/customerAdmin.js ###"
grep -n "phone_verified\|otp_outbox\|otp_code\|otp_expires\|phone" lib/customerAdmin.js || true
echo
echo "### each POST/PUT/PATCH handler (the SAVE) with context ###"
node - <<'NODE'
const fs=require('fs');
const s=fs.readFileSync('lib/customerAdmin.js','utf8').split('\n');
for(let i=0;i<s.length;i++){
  if(/router\.(post|put|patch)\(/.test(s[i])){
    console.log('=== line '+(i+1)+' ===');
    for(let j=i;j<Math.min(i+60,s.length);j++) console.log((j+1)+': '+s[j]);
    console.log();
  }
}
NODE
echo DONE
