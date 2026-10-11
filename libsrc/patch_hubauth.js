'use strict';
/* Make the customer /forgot and /reset routes answer JSON when the Galaxy Hub calls them
   with fetch (header X-Requested-With: fetch), so forgot-password works INSIDE the Hub
   (hub_model.ejs forgotForm()/resetForm()). Direct page loads keep rendering as before.
   sendResetCode already sends to both email and the linked/verified WhatsApp.
   Idempotent; aborts if an anchor moved (step script auto-restores on failure). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_hubauth.js <ROOT>'); process.exit(1); }

function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    const i = s.indexOf(e.find);
    if (i < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
    if (s.indexOf(e.find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
    s = s.slice(0, i) + e.repl + s.slice(i + e.find.length);
    console.log('patched: ' + rel + ' :: ' + e.name);
  }
  fs.writeFileSync(file, s);
}

patch('routes/account.js', [
  { name: 'forgot-ajax', guard: "res.json({ ok: false, error: 'No account found with that email or WhatsApp number.' })",
    find:
"  router.post('/forgot', body, async (req, res) => {\n" +
"    let c = null;\n" +
"    try { c = await findByIdf(req.body.idf, req.body.wa_country); } catch (e) {}\n" +
"    if (!c) {\n" +
"      return shell().then(s => res.render('account/forgot', Object.assign(s, { title: 'Forgot password', error: 'No account found with that email or phone number.', idf: req.body.idf || '', noacct: true })));\n" +
"    }\n" +
"    try { await sendResetCode(c); } catch (e) {}\n" +
"    req.session.pwreset = { cid: c.id, at: Date.now() };\n" +
"    res.redirect('/reset?sent=1');\n" +
"  });",
    repl:
"  router.post('/forgot', body, async (req, res) => {\n" +
"    const ajax = req.xhr || req.get('X-Requested-With') === 'fetch';\n" +
"    let c = null;\n" +
"    try { c = await findByIdf(req.body.idf, req.body.wa_country); } catch (e) {}\n" +
"    if (!c) {\n" +
"      if (ajax) return res.json({ ok: false, error: 'No account found with that email or WhatsApp number.' });\n" +
"      return shell().then(s => res.render('account/forgot', Object.assign(s, { title: 'Forgot password', error: 'No account found with that email or phone number.', idf: req.body.idf || '', noacct: true })));\n" +
"    }\n" +
"    try { await sendResetCode(c); } catch (e) {}\n" +
"    req.session.pwreset = { cid: c.id, at: Date.now() };\n" +
"    if (ajax) return res.json({ ok: true });\n" +
"    res.redirect('/reset?sent=1');\n" +
"  });" },
  { name: 'reset-re-ajax', guard: "ajax ? res.json({ ok: false, error: err })",
    find: "    const re = (err) => shell().then(s => res.render('account/reset', Object.assign(s, { title: 'Reset password', error: err, sent: false })));",
    repl: "    const ajax = req.xhr || req.get('X-Requested-With') === 'fetch';\n    const re = (err) => ajax ? res.json({ ok: false, error: err }) : shell().then(s => res.render('account/reset', Object.assign(s, { title: 'Reset password', error: err, sent: false })));" },
  { name: 'reset-success-ajax', guard: "if (ajax) return res.json({ ok: true });\n      res.redirect('/account?ok=pw');",
    find: "      res.redirect('/account?ok=pw');",
    repl: "      if (ajax) return res.json({ ok: true });\n      res.redirect('/account?ok=pw');" }
]);

console.log('HUB AUTH (forgot/reset AJAX) OK');
