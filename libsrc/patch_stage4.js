'use strict';
/* STAGE4_v1 — buffer slider on /admin/payments (writes wa_settings.price_buffer_pct) + mount the
   owner price endpoint. Idempotent (done-marker-first); split/join; throws on a miss so the step
   restores. ownerPrice.js is copied into routes/ by the step (not by this patcher). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';

const BUFFER_ROUTE =
  "  // --- set the foreign-price buffer % (converted local currencies only) ---\n" +
  "  router.post('/payments/buffer', auth, express.urlencoded({ extended: true }), async (req, res) => {\n" +
  "    let v = parseFloat(req.body && req.body.buffer); if (!Number.isFinite(v)) v = 0; v = Math.max(0, Math.min(90, v));\n" +
  "    try { await pool.query(\"INSERT INTO wa_settings(key,value) VALUES('price_buffer_pct',$1) ON CONFLICT(key) DO UPDATE SET value=$1, updated_at=now()\", [String(v)]); } catch (e) {}\n" +
  "    res.redirect('/admin/payments?ok=' + encodeURIComponent('Buffer saved: ' + v + '%'));\n" +
  "  });\n\n  return router;";

const BUFFER_CARD =
  "<div class=\"card\">\n" +
  "  <h2 style=\"margin:0 0 4px\">Foreign price buffer</h2>\n" +
  "  <div class=\"sub\" style=\"margin:0 0 12px\">Shave a margin off auto-converted foreign prices (your profit). Applies only to the local currencies shown to non-Pakistan visitors — never your PKR prices or your set USD prices. Example: 3% shows a £10 conversion as £9.70.</div>\n" +
  "  <form method=\"post\" action=\"/admin/payments/buffer\" style=\"display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin:0\">\n" +
  "    <input type=\"range\" name=\"buffer\" min=\"0\" max=\"30\" step=\"0.5\" value=\"<%= Number(buffer||0) %>\" oninput=\"document.getElementById('bufval').textContent=this.value+'%'\" style=\"flex:1;min-width:200px;max-width:380px\">\n" +
  "    <b id=\"bufval\" style=\"min-width:52px;color:#2a7bff;font-size:17px\"><%= Number(buffer||0) %>%</b>\n" +
  "    <button class=\"btn btn-p\" type=\"submit\">Save buffer</button>\n" +
  "  </form>\n" +
  "</div>\n\n";

const edits = [
  // adminPayments.js — read buffer into the render locals
  { file: 'routes/adminPayments.js',
    old: "    res.render('admin/payments', { methods, source, flash: req.query.ok || null, active: 'payments', title: 'Payments' });",
    neu: "    let priceBuffer = 0; try { const _b = (await pool.query(\"SELECT value FROM wa_settings WHERE key='price_buffer_pct'\")).rows[0]; priceBuffer = _b ? (parseFloat(_b.value) || 0) : 0; } catch (e) {}\n    res.render('admin/payments', { methods, source, buffer: priceBuffer, flash: req.query.ok || null, active: 'payments', title: 'Payments' });",
    done: "buffer: priceBuffer," },

  // adminPayments.js — buffer save route before `return router;`
  { file: 'routes/adminPayments.js',
    old: "  return router;",
    neu: BUFFER_ROUTE,
    done: "/payments/buffer" },

  // payments.ejs — buffer card above the methods list
  { file: 'views/admin/payments.ejs',
    old: "<% if (!methods.length) { %>",
    neu: BUFFER_CARD + "<% if (!methods.length) { %>",
    done: "Foreign price buffer" },

  // server.js — mount the owner price endpoint
  { file: 'server.js',
    old: "const adminPaymentsRouter = require('./routes/adminPayments')(pool);\napp.use('/admin', adminPaymentsRouter);",
    neu: "const adminPaymentsRouter = require('./routes/adminPayments')(pool);\napp.use('/admin', adminPaymentsRouter);\nconst ownerPriceRouter = require('./routes/ownerPrice')(pool);\napp.use('/', ownerPriceRouter);",
    done: "ownerPriceRouter" },
];

const cache = {};
function load(f) { if (!(f in cache)) cache[f] = fs.readFileSync(path.join(ROOT, f), 'utf8'); return cache[f]; }
let applied = 0, skipped = 0;
for (const e of edits) {
  let s = load(e.file);
  if (s.indexOf(e.done) >= 0) { skipped++; continue; }
  const n = s.split(e.old).length - 1;
  if (n === 0) throw new Error('ANCHOR MISSING in ' + e.file + ': ' + e.old.slice(0, 55));
  if (n !== 1) throw new Error('anchor not unique (' + n + ') in ' + e.file + ': ' + e.old.slice(0, 40));
  cache[e.file] = s.split(e.old).join(e.neu); applied++;
}
for (const f in cache) fs.writeFileSync(path.join(ROOT, f), cache[f]);
console.log('STAGE4_v1 applied=' + applied + ' skipped=' + skipped);
