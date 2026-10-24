'use strict';
/* Phase 2 — household = tap-link (new portal has no server household endpoint).
   account.js: /account/tools/household/:no now resolves the account's household-update
   code link (via nfMail + gate, tier-gated) and returns it. hub_model.ejs: the "Update
   Household" button opens that link instead of calling the dead updateHousehold. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_nfhousehold2.js <ROOT>'); process.exit(1); }

function span(file, name, guard, startStr, endStr, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(startStr); if (i < 0) throw new Error('START MISS: ' + name);
  if (s.indexOf(startStr, i + startStr.length) >= 0) throw new Error('START NOT UNIQUE: ' + name);
  const j = s.indexOf(endStr, i); if (j < 0) throw new Error('END MISS: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(j + endStr.length));
  console.log('patched: ' + name);
}
function sub(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find); if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}

/* --- account.js: replace the updateHousehold block with a household-link resolver --- */
const AC = path.join(ROOT, 'routes/account.js');
const START = "let nfPortal=null; try{ nfPortal=require('../lib/nfPortal'); }catch(e){}";
const END = "return res.json(r||{ ok:false, reason:'error' });";
const NEW =
"let nfMail=null; try{ nfMail=require('../lib/nfMail'); }catch(e){}\n" +
"      const _gate=require('../lib/netflixGate');\n" +
"      if(!(nfMail && nfMail.configured && nfMail.configured())) return res.json({ ok:false, reason:'not_supported' });\n" +
"      let _plabel=''; try{ _plabel=(((await pool.query(\"SELECT plan_label FROM orders WHERE order_no=$1 LIMIT 1\",[o.order_no])).rows[0])||{}).plan_label||''; }catch(e){}\n" +
"      let _acctRef=null; try{ _acctRef=(((await pool.query(\"SELECT account_ref FROM inventory_items WHERE order_no=$1 AND account_ref IS NOT NULL LIMIT 1\",[o.order_no])).rows[0])||{}).account_ref||null; }catch(e){}\n" +
"      if(!_acctRef) return res.json({ ok:false, reason:'waiting' });\n" +
"      const _m=await nfMail.listForAccount(_acctRef, true);\n" +
"      if(!(_m && _m.ok)) return res.json({ ok:false, reason:'waiting' });\n" +
"      const _hh=(_gate.filterEmails(_m.emails, _plabel)||[]).filter(function(e){ return e.rtype==='household_update' && e.link; }).sort(function(a,b){ return String(b.date||'')>String(a.date||'')?1:-1; })[0];\n" +
"      if(_hh && _hh.link) return res.json({ ok:true, kind:'link', value: _hh.link });\n" +
"      return res.json({ ok:false, reason:'waiting' });";
span(AC, 'account:household', 'nfMail.listForAccount(_acctRef', START, END, NEW);

/* --- hub_model.ejs: the Update Household button opens the resolved link --- */
const HB = path.join(ROOT, 'views/partials/hub_model.ejs');
sub(HB, 'hub:household-link', 'Open Household Link',
  "(j&&j.ok)?'<div class=\"okmsg\" style=\"margin:8px 0 2px\">✅ Household Updated</div>':",
  "(j&&j.ok&&j.value)?('<div style=\"margin:8px 0 2px\"><a class=\"cbtn cbtn-p\" target=\"_blank\" rel=\"noopener\" href=\"'+esc(j.value)+'\">Open Household Link</a></div>'):");

console.log('NF HOUSEHOLD PHASE2 PATCH OK');
