'use strict';
/* Re-point the Hub's "Update Household" endpoint from gsz-api (bot) to the Netflix Portal.
   Household lives in the Accounts Portal, not the reseller bot. Owner-gating + wa lookup
   stay the same; only the call target changes. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_household_repoint.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('nfPortal.updateHousehold') >= 0) { console.log('skip (already): household points at nfPortal'); console.log('HOUSEHOLD REPOINT PATCH OK'); process.exit(0); }

const reps = [
  [ "      let botapi=null; try{ botapi=require('../lib/botapi'); }catch(e){}\n      if(!(botapi && typeof botapi.updateHousehold==='function')) return res.json({ ok:false, reason:'not_supported' });",
    "      let nfPortal=null; try{ nfPortal=require('../lib/nfPortal'); }catch(e){}\n      if(!(nfPortal && nfPortal.configured && nfPortal.configured() && typeof nfPortal.updateHousehold==='function')) return res.json({ ok:false, reason:'not_supported' });" ],
  [ "      const r=await botapi.updateHousehold(o.order_no, wa);",
    "      const r=await nfPortal.updateHousehold({ order_no:o.order_no, whatsapp:wa });" ]
];
for (const [oldS, newS] of reps) {
  if (s.indexOf(oldS) < 0) throw new Error('ANCHOR MISS: household block not in expected form:\n' + oldS.slice(0, 60));
  s = s.replace(oldS, newS);
}
fs.writeFileSync(file, s);
console.log('patched: household endpoint now calls nfPortal (Netflix Portal)');
console.log('HOUSEHOLD REPOINT PATCH OK');
