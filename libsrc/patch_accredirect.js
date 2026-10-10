'use strict';
/* /account no longer renders a separate dashboard page — it redirects straight into the shared Hub
   model (home + ?tool=purchases). The Hub already provides subscriptions, access, renew, trials,
   claim and account, so the dashboard page was pure duplication. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_accredirect.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

const OLD = "    res.render('account/dashboard', Object.assign(await shell(), { title: 'Dashboard', c, ok: req.query.ok || null, wa, orders, announcements, stats, qa, activeProducts, ticketsOpen, totalSpent, products, payMethods, memberSince, refCode, location }));";
const NEW = "    res.redirect('/?tool=purchases');";

if (s.indexOf(NEW) >= 0 && s.indexOf(OLD) < 0) { console.log('skip (already redirecting)'); console.log('ACCREDIRECT OK'); process.exit(0); }
if (s.indexOf(OLD) < 0) { throw new Error('ANCHOR MISS: dashboard render not found in account.js'); }
s = s.replace(OLD, NEW);
fs.writeFileSync(file, s);
console.log('patched: GET /account -> redirect /?tool=purchases (Hub)');
console.log('ACCREDIRECT OK');
