'use strict';
/* routes/trials.js: when a non-ajax trial claim finds WhatsApp unverified, send the customer
   to the Hub (/?tool=trials) instead of the old /account/whatsapp page. The Hub flow is ajax
   (reason:'wa') so this is the belt-and-suspenders path. Idempotent; hard-fails if missing. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_trialredirect.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/trials.js');
let s = fs.readFileSync(file, 'utf8');
const OLD = "res.redirect('/account/whatsapp')";
const NEW = "res.redirect('/?tool=trials')";
if (s.indexOf(NEW) >= 0) { console.log('trial redirect: already (skip)'); }
else if (s.indexOf(OLD) >= 0) { s = s.split(OLD).join(NEW); fs.writeFileSync(file, s); console.log('trial redirect: -> /?tool=trials'); }
else { console.error('PATCH FAILED — /account/whatsapp redirect not found'); process.exit(2); }
console.log('TRIALREDIRECT OK');
