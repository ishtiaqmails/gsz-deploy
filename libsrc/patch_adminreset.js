'use strict';
/* Wire the admin password-reset feature:
   - server.js: mount routes/adminReset.js (after adminWhatsapp)
   - routes/admin.js: login checks admin_auth (DB hash) first, falls back to .env ADMIN_PASS
   Idempotent; aborts if an anchor is missing or not unique. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_adminreset.js <ROOT>'); process.exit(1); }

function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    const first = s.indexOf(e.find);
    if (first < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
    if (s.indexOf(e.find, first + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
    s = s.slice(0, first) + e.repl + s.slice(first + e.find.length);
    console.log('patched: ' + rel + ' :: ' + e.name);
  }
  fs.writeFileSync(file, s);
}

const SV_FIND = "const adminWhatsappRouter = require('./routes/adminWhatsapp')(pool);\napp.use('/admin', adminWhatsappRouter);";
const SV_REPL = SV_FIND + "\nconst adminResetRouter = require('./routes/adminReset')(pool);\napp.use('/admin', adminResetRouter);";

const LOGIN_FIND = [
  "  router.post('/login', express.urlencoded({ extended: false }), (req, res) => {",
  "    const { username, password } = req.body || {};",
  "    if (username === process.env.ADMIN_USER && password === process.env.ADMIN_PASS) {",
  "      req.session.admin = true;",
  "      return res.redirect('/admin');",
  "    }",
  "    res.status(401).render('admin/login', { error: 'Wrong username or password.' });",
  "  });"
].join('\n');

const LOGIN_REPL = [
  "  router.post('/login', express.urlencoded({ extended: false }), async (req, res) => {",
  "    const { username, password } = req.body || {};",
  "    let ok = false;",
  "    if (username === process.env.ADMIN_USER) {",
  "      let hash = null;",
  "      try { const r = await pool.query('SELECT pass_hash FROM admin_auth WHERE id=1'); hash = r.rows[0] && r.rows[0].pass_hash; } catch (e) {}",
  "      if (hash) {",
  "        try { const crypto = require('crypto'); const parts = String(hash).split(':'); const hh = crypto.scryptSync(String(password), Buffer.from(parts[0], 'hex'), 64); const hb = Buffer.from(parts[1], 'hex'); ok = hh.length === hb.length && crypto.timingSafeEqual(hh, hb); } catch (e) { ok = false; }",
  "      } else {",
  "        ok = (password === process.env.ADMIN_PASS);",
  "      }",
  "    }",
  "    if (ok) { req.session.admin = true; return res.redirect('/admin'); }",
  "    res.status(401).render('admin/login', { error: 'Wrong username or password.' });",
  "  });"
].join('\n');

patch('server.js', [
  { name: 'mount-admin-reset', guard: 'routes/adminReset', find: SV_FIND, repl: SV_REPL }
]);
patch('routes/admin.js', [
  { name: 'login-db-password', guard: 'SELECT pass_hash FROM admin_auth', find: LOGIN_FIND, repl: LOGIN_REPL }
]);

console.log('ALL PATCHES APPLIED');
