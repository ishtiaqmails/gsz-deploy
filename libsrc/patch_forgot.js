'use strict';
/* Customer forgot-password routing: when no account matches the email/phone, show
   "No account found" on the Forgot page (with a Create-one link) instead of sending
   the visitor to the reset-code page for a code that was never sent. Targets the
   /forgot POST handler in routes/account.js. Idempotent; aborts if the anchor moved. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_forgot.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf('noacct: true') >= 0) { console.log('forgot route: already patched (skip)'); process.exit(0); }

const FIND = [
  "  router.post('/forgot', body, async (req, res) => {",
  "    try {",
  "      const c = await findByIdf(req.body.idf, req.body.wa_country);",
  "      if (c) { try { await sendResetCode(c); } catch (e) {} req.session.pwreset = { cid: c.id, at: Date.now() }; }",
  "    } catch (e) {}",
  "    res.redirect('/reset?sent=1');",
  "  });"
].join('\n');

const REPL = [
  "  router.post('/forgot', body, async (req, res) => {",
  "    let c = null;",
  "    try { c = await findByIdf(req.body.idf, req.body.wa_country); } catch (e) {}",
  "    if (!c) {",
  "      return shell().then(s => res.render('account/forgot', Object.assign(s, { title: 'Forgot password', error: 'No account found with that email or phone number.', idf: req.body.idf || '', noacct: true })));",
  "    }",
  "    try { await sendResetCode(c); } catch (e) {}",
  "    req.session.pwreset = { cid: c.id, at: Date.now() };",
  "    res.redirect('/reset?sent=1');",
  "  });"
].join('\n');

const i = s.indexOf(FIND);
if (i < 0) throw new Error('ANCHOR MISS: /forgot POST handler not found as expected');
if (s.indexOf(FIND, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE');
s = s.slice(0, i) + REPL + s.slice(i + FIND.length);
fs.writeFileSync(file, s);
console.log('forgot route: no-account now shown on the Forgot page');
