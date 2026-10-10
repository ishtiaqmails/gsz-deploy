'use strict';
/* Admin: view & decide customer replacement requests (order_issues).
   Mounted at '/admin'. Owner-facing surface, works with no bot.
   Decisions: approve-from-stock (pulls inventory_items), manual replacement,
   fix & respond (with screenshot), reject. Each writes a response the customer sees. */
const express = require('express');
const path = require('path');

const KINDS = { not_working: 'Not working', wrong_details: 'Wrong login details', expired_early: 'Expired too early', replacement: 'Replacement request', other: 'Something else' };
const STATUSES = ['open', 'resolved', 'replaced', 'rejected'];
const DECISIONS = { stock: 'Replaced from stock', manual: 'Manual replacement', fix: 'Fixed & responded', reject: 'Declined' };

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  const UPDIR = path.join(__dirname, '..', 'uploads');
  try { require('fs').mkdirSync(UPDIR, { recursive: true }); } catch (e) {}
  const upShot = require('multer')({
    storage: require('multer').diskStorage({
      destination: function (q, f, cb) { cb(null, UPDIR); },
      filename: function (q, f, cb) { var e = (String(f.originalname || '').match(/\.[a-z0-9]+$/i) || ['.png'])[0]; cb(null, 'adm-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8) + e.toLowerCase()); }
    }),
    limits: { fileSize: 12 * 1024 * 1024 },
    fileFilter: function (q, f, cb) { cb(null, /\.(png|jpe?g|webp|gif|heic|heif|pdf)$/i.test(f.originalname || '')); }
  });

  router.get('/issues', auth, async (req, res) => {
    const filter = (STATUSES.includes(req.query.status) || req.query.status === 'all') ? req.query.status : 'open';
    let rows = [];
    try {
      rows = (await pool.query(
        `SELECT i.*, o.product_name AS o_product, o.plan_label AS o_plan, o.status AS o_status, o.id AS o_id,
                c.name AS c_name, c.email AS c_email, c.wa_number AS c_wa
         FROM order_issues i
         LEFT JOIN orders o ON o.id = i.order_id
         LEFT JOIN customers c ON c.id = i.customer_id
         WHERE ($1 = 'all' OR i.status = $1)
         ORDER BY (i.status = 'open') DESC, i.id DESC LIMIT 200`, [filter])).rows;
    } catch (e) { rows = []; }
    // resolve available stock for open rows (so admin knows if "from stock" will work)
    for (const r of rows) {
      r._stock = 0; r._plan_id = null;
      if (r.status === 'open' && r.o_id) {
        try {
          const pr = await pool.query("SELECT pp.id FROM product_plans pp JOIN orders o ON o.product_id=pp.product_id AND o.plan_label=pp.label WHERE o.id=$1 LIMIT 1", [r.o_id]);
          if (pr.rows[0]) { r._plan_id = pr.rows[0].id; const sc = await pool.query("SELECT count(*)::int n FROM inventory_items WHERE plan_id=$1 AND status='available'", [r._plan_id]); r._stock = sc.rows[0].n; }
        } catch (e) {}
      }
    }
    let counts = {};
    try { (await pool.query("SELECT status, count(*)::int n FROM order_issues GROUP BY status")).rows.forEach(r => counts[r.status] = r.n); } catch (e) {}
    res.render('admin/issues', { rows, filter, counts, kinds: KINDS, decisions: DECISIONS, flash: req.query.ok || null });
  });

  // stream a screenshot (customer's or admin's) — admin only, must exist on a real issue
  router.get('/issue-file/:name', auth, async (req, res) => {
    const name = path.basename(String(req.params.name || ''));
    try {
      const ok = (await pool.query("SELECT 1 FROM order_issues WHERE screenshot=$1 OR admin_screenshot=$1 LIMIT 1", [name])).rows[0];
      if (!ok) return res.status(404).end();
      return res.sendFile(path.join(UPDIR, name));
    } catch (e) { res.status(404).end(); }
  });

  // legacy simple status flip (kept for Reopen)
  router.post('/issues/:id/status', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const st = STATUSES.includes(req.body.status) ? req.body.status : null;
    const back = STATUSES.includes(req.body.back) || req.body.back === 'all' ? req.body.back : 'open';
    if (!id || !st) return res.redirect('/admin/issues?status=' + encodeURIComponent(back) + '&ok=' + encodeURIComponent('No change'));
    try {
      if (st === 'open') await pool.query("UPDATE order_issues SET status=$1, decision=NULL, resolved_at=NULL WHERE id=$2", [st, id]);
      else await pool.query("UPDATE order_issues SET status=$1, resolved_at=now() WHERE id=$2", [st, id]);
    } catch (e) {}
    res.redirect('/admin/issues?status=' + encodeURIComponent(back) + '&ok=' + encodeURIComponent('Updated'));
  });

  // the decision console
  router.post('/issues/:id/decide', auth, function (req, res) { upShot.single('shot')(req, res, function () { decide(req, res); }); });
  async function decide(req, res) {
    const id = parseInt(req.params.id, 10) || 0;
    const action = String(req.body.action || '');
    const back = (STATUSES.includes(req.body.back) || req.body.back === 'all') ? req.body.back : 'open';
    const response = String(req.body.response || '').trim().slice(0, 2000);
    const creds = String(req.body.credentials || '').trim();
    const shot = (req.file && req.file.filename) ? req.file.filename : null;
    let flash = 'Updated';
    const go = () => res.redirect('/admin/issues?status=' + encodeURIComponent(back) + '&ok=' + encodeURIComponent(flash));
    if (!id || !action) { flash = 'No change'; return go(); }
    try {
      const i = (await pool.query("SELECT i.*, o.id AS oid FROM order_issues i LEFT JOIN orders o ON o.id=i.order_id WHERE i.id=$1", [id])).rows[0];
      if (!i) { flash = 'No change'; return go(); }

      if (action === 'open') {
        await pool.query("UPDATE order_issues SET status='open', decision=NULL, resolved_at=NULL WHERE id=$1", [id]);
        flash = 'Reopened';

      } else if (action === 'reject') {
        await pool.query("UPDATE order_issues SET status='rejected', decision='reject', admin_response=$2, admin_screenshot=COALESCE($3,admin_screenshot), resolved_at=now() WHERE id=$1", [id, response || null, shot]);
        flash = 'Declined';

      } else if (action === 'fix') {
        await pool.query("UPDATE order_issues SET status='resolved', decision='fix', admin_response=$2, admin_screenshot=COALESCE($3,admin_screenshot), resolved_at=now() WHERE id=$1", [id, response || null, shot]);
        flash = 'Fixed & responded';

      } else if (action === 'manual') {
        if (!creds) { flash = 'Enter the new credentials for a manual replacement'; return go(); }
        await pool.query("UPDATE order_issues SET status='replaced', decision='manual', replacement_credentials=$2, admin_response=$3, admin_screenshot=COALESCE($4,admin_screenshot), resolved_at=now() WHERE id=$1", [id, creds, response || null, shot]);
        if (i.oid) await pool.query("UPDATE orders SET delivered_credentials=$2 WHERE id=$1", [i.oid, creds]);
        flash = 'Replaced (manual)';

      } else if (action === 'stock') {
        let pid = null, pick = null;
        if (i.oid) { const pr = await pool.query("SELECT pp.id FROM product_plans pp JOIN orders o ON o.product_id=pp.product_id AND o.plan_label=pp.label WHERE o.id=$1 LIMIT 1", [i.oid]); pid = pr.rows[0] && pr.rows[0].id; }
        if (pid) { const pk = await pool.query("SELECT id, payload FROM inventory_items WHERE plan_id=$1 AND status='available' ORDER BY id ASC LIMIT 1", [pid]); pick = pk.rows[0]; }
        if (!pick) { flash = 'No stock available — use Manual replacement'; return go(); }
        await pool.query("UPDATE inventory_items SET status='used', order_no=$2, delivered_at=now() WHERE id=$1", [pick.id, i.order_no || null]);
        await pool.query("UPDATE order_issues SET status='replaced', decision='stock', replacement_credentials=$2, admin_response=$3, admin_screenshot=COALESCE($4,admin_screenshot), resolved_at=now() WHERE id=$1", [id, pick.payload, response || null, shot]);
        if (i.oid) await pool.query("UPDATE orders SET delivered_credentials=$2 WHERE id=$1", [i.oid, pick.payload]);
        flash = 'Replaced from stock';

      } else { flash = 'No change'; return go(); }

      // best-effort customer ping on a completed replacement/fix
      try {
        const botapi = require('../lib/botapi');
        if ((action === 'stock' || action === 'manual' || action === 'fix') && botapi.configured && botapi.configured()) {
          await botapi.notify({ event: 'issue_update', type: 'issue_update', order_no: i.order_no, issue_id: id, status: flash, message: (response || flash).slice(0, 400) });
        }
      } catch (e) {}
    } catch (e) { flash = 'Error — not saved'; }
    go();
  }

  return router;
};
