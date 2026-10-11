'use strict';
/* Retire the customer dashboard: /account and its sub-pages now redirect into the shared Hub model
   (home + ?tool=...). The Hub already provides subscriptions, access, renew, trials, claim and
   account. The /account/tools/* and /account/order/:no/* APIs the Hub relies on are NOT touched.
   Two independent, idempotent parts. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_accredirect.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');
let changed = false;

// Part A: GET /account dashboard render -> redirect (idempotent)
const OLD = "    res.render('account/dashboard', Object.assign(await shell(), { title: 'Dashboard', c, ok: req.query.ok || null, wa, orders, announcements, stats, qa, activeProducts, ticketsOpen, totalSpent, products, payMethods, memberSince, refCode, location }));";
const NEW = "    res.redirect('/?tool=purchases');";
if (s.indexOf(OLD) >= 0) { s = s.replace(OLD, NEW); changed = true; console.log('A: /account render -> redirect'); }
else { console.log('A: already redirecting (skip)'); }

// Part B: retire the dashboard page routes via a top-of-router redirect (runs before the old handlers)
if (s.indexOf('dashboard-pages-retired') < 0) {
  const ra = "const router = express.Router();";
  const ri = s.indexOf(ra);
  if (ri >= 0) {
    const insAt = s.indexOf('\n', ri) + 1;
    const route =
      "  /* dashboard-pages-retired: these now open the Hub model instead of a dashboard page */\n" +
      "  router.get(['/account','/account/orders','/account/products','/account/codes','/account/security','/account/support'], function(req,res){ var _m={'/account/codes':'code','/account/security':'account','/account/support':'claim'}; res.redirect('/?tool='+(_m[req.path]||'purchases')); });\n";
    s = s.slice(0, insAt) + route + s.slice(insAt);
    changed = true; console.log('B: dashboard pages -> Hub (retired)');
  } else { console.log('B: router anchor not found (skip)'); }
} else { console.log('B: already retired (skip)'); }

if (changed) fs.writeFileSync(file, s);
console.log('ACCREDIRECT OK');
