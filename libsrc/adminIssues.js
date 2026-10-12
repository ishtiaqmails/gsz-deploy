'use strict';
/* Admin: customer issue / replacement threads (order_issues + issue_messages).
   Mounted at '/admin'. Owner-facing; works with no bot.
   - /issues            : list (3+ stat cards, filters, unread markers)
   - /issues/:id        : full chat thread — reply (text + screenshot), quick
                          templates, product-type guidance, and the replacement
                          actions (from-stock / manual / fix / reject / reopen),
                          each mirrored into the thread and pinged to the customer.
   Every admin message best-effort pings the customer's WhatsApp via botapi.notify. */
const express = require('express');
const path = require('path');

const KINDS = { not_working: 'Not working', wrong_details: 'Wrong login details', expired_early: 'Expired too early', replacement: 'Replacement request', other: 'Something else' };
const STATUSES = ['open', 'resolved', 'replaced', 'rejected'];
const DECISIONS = { stock: 'Replaced from stock', manual: 'Manual replacement', fix: 'Fixed & responded', reject: 'Declined' };
const TEMPLATES = [
  "Thanks for reaching out — I'm looking into this now and will update you shortly.",
  "Could you send a screenshot of exactly what you're seeing? It helps me fix it faster.",
  "This is fixed on our end — please fully close and reopen the app, then try again.",
  "I've sent you a replacement — the new access is below. Please confirm it works.",
  "I've renewed your line — give it a few minutes, then check again and let me know."
];

function guidance(plan, stock) {
  const g = { type: 'manual', title: 'Manual replacement', hint: 'Send fresh credentials to the customer.', stock: stock || 0, stockReady: (stock || 0) > 0 };
  if (!plan) return g;
  const dt = String(plan.delivery_type || '').toLowerCase();
  if (plan.nf_portal_product_id) { g.type = 'netflix'; g.title = 'Netflix account'; g.hint = 'Swap the household/profile or issue a fresh invite, then paste the new access below.'; }
  else if (dt === 'iptv' || String(plan.bot_type || '').toLowerCase().indexOf('iptv') >= 0) { g.type = 'iptv'; g.title = 'IPTV line'; g.hint = 'Best fix is to renew/replace the line on the panel. Activation panels (Trex / Strong 8K) need the line password. Paste the renewed line as the new access.'; }
  else if (String(plan.source || '') === 'bot') { g.type = 'bot'; g.title = 'Bot-fulfilled'; g.hint = 'Re-deliver through the bot, or paste fresh credentials as a manual replacement.'; }
  else if (g.stockReady) { g.hint = 'Stock is available — one-click “Replace from stock” will pull the next item and send it.'; }
  return g;
}

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

  async function addMsg(issueId, sender, text, shot) {
    try {
      await pool.query(
        "INSERT INTO issue_messages(issue_id,sender,body,screenshot,seen_by_admin,seen_by_customer) VALUES($1,$2,$3,$4,$5,$6)",
        [issueId, sender, (text || null), (shot || null), sender === 'admin', sender === 'customer']);
    } catch (e) {}
  }
  // Customer-facing WhatsApp goes through the Verification Bot (wa_notifications
  // outbox -> wa_bot_send_url), NEVER the reseller bot.
  async function pingCustomer(issue, text) {
    try {
      if (!issue || !issue.customer_id) return;
      require('../lib/wanotify')(pool).enqueue({
        customer_id: issue.customer_id,
        order_id: issue.order_id || null,
        template_key: 'whatsapp.issue_update',
        vars: { order_no: issue.order_no || '', message: String(text || '').slice(0, 900), account_url: 'https://galaxyzayron.store/account' },
        idempotency_key: 'issmsg-' + issue.id + '-' + Math.random().toString(36).slice(2, 10)
      });
    } catch (e) {}
  }

  // ---- list ----
  router.get('/issues', auth, async (req, res) => {
    const filter = (STATUSES.includes(req.query.status) || req.query.status === 'all') ? req.query.status : 'open';
    let rows = [];
    try {
      rows = (await pool.query(
        `SELECT i.*, o.product_name AS o_product, o.plan_label AS o_plan, o.status AS o_status, o.id AS o_id,
                c.name AS c_name, c.email AS c_email, c.wa_number AS c_wa,
                (SELECT count(*) FROM issue_messages m WHERE m.issue_id=i.id AND m.sender='customer' AND m.seen_by_admin=false)::int AS unread,
                (SELECT max(created_at) FROM issue_messages m WHERE m.issue_id=i.id) AS last_msg
         FROM order_issues i
         LEFT JOIN orders o ON o.id = i.order_id
         LEFT JOIN customers c ON c.id = i.customer_id
         WHERE ($1 = 'all' OR i.status = $1)
         ORDER BY (i.status = 'open') DESC, i.id DESC LIMIT 200`, [filter])).rows;
    } catch (e) { rows = []; }
    let counts = {};
    try { (await pool.query("SELECT status, count(*)::int n FROM order_issues GROUP BY status")).rows.forEach(r => counts[r.status] = r.n); } catch (e) {}
    res.render('admin/issues', { rows, filter, counts, kinds: KINDS, decisions: DECISIONS, flash: req.query.ok || null });
  });

  // ---- single thread ----
  router.get('/issues/:id', auth, async (req, res) => {
    const id = parseInt(req.params.id, 10) || 0;
    let i = null;
    try {
      i = (await pool.query(
        `SELECT i.*, o.product_name AS o_product, o.plan_label AS o_plan, o.status AS o_status, o.id AS o_id, o.delivered_credentials,
                c.name AS c_name, c.email AS c_email, c.wa_number AS c_wa
         FROM order_issues i LEFT JOIN orders o ON o.id = i.order_id LEFT JOIN customers c ON c.id = i.customer_id
         WHERE i.id=$1`, [id])).rows[0] || null;
    } catch (e) {}
    if (!i) return res.redirect('/admin/issues');
    let plan = null, stock = 0;
    if (i.o_id) {
      try {
        plan = (await pool.query(
          `SELECT pp.id, pp.label, pp.source, pp.bot_sku, pp.bot_type, pp.nf_portal_product_id, bp.delivery_type
           FROM product_plans pp JOIN orders o ON o.product_id=pp.product_id AND o.plan_label=pp.label
           LEFT JOIN bot_products bp ON bp.sku = pp.bot_sku WHERE o.id=$1 LIMIT 1`, [i.o_id])).rows[0] || null;
        if (plan) { const sc = await pool.query("SELECT count(*)::int n FROM inventory_items WHERE plan_id=$1 AND status='available'", [plan.id]); stock = sc.rows[0].n; }
      } catch (e) {}
    }
    let msgs = [];
    try { msgs = (await pool.query("SELECT * FROM issue_messages WHERE issue_id=$1 ORDER BY id ASC", [id])).rows; } catch (e) {}
    try { await pool.query("UPDATE issue_messages SET seen_by_admin=true WHERE issue_id=$1 AND sender='customer' AND seen_by_admin=false", [id]); } catch (e) {}
    res.render('admin/issue', { i, plan, stock, msgs, guide: guidance(plan, stock), templates: TEMPLATES, kinds: KINDS, decisions: DECISIONS, flash: req.query.ok || null });
  });

  // stream a screenshot (customer's, admin's, or any thread message) — admin only
  router.get('/issue-file/:name', auth, async (req, res) => {
    const name = path.basename(String(req.params.name || ''));
    try {
      const ok = (await pool.query(
        "SELECT 1 FROM order_issues WHERE screenshot=$1 OR admin_screenshot=$1 UNION SELECT 1 FROM issue_messages WHERE screenshot=$1 LIMIT 1", [name])).rows[0];
      if (!ok) return res.status(404).end();
      return res.sendFile(path.join(UPDIR, name));
    } catch (e) { res.status(404).end(); }
  });

  // ---- free-form admin reply into the thread ----
  router.post('/issues/:id/message', auth, function (req, res) { upShot.single('shot')(req, res, function () { postMsg(req, res); }); });
  async function postMsg(req, res) {
    const id = parseInt(req.params.id, 10) || 0;
    const text = String(req.body.body || '').trim().slice(0, 4000);
    const shot = (req.file && req.file.filename) ? req.file.filename : null;
    if (!id || (!text && !shot)) return res.redirect('/admin/issues/' + id + '#end');
    let issue = null;
    try { issue = (await pool.query("SELECT * FROM order_issues WHERE id=$1", [id])).rows[0]; } catch (e) {}
    if (!issue) return res.redirect('/admin/issues');
    await addMsg(id, 'admin', text, shot);
    await pingCustomer(issue, text || '(screenshot)');
    res.redirect('/admin/issues/' + id + '#end');
  }

  // legacy simple status flip (kept for Reopen)
  router.post('/issues/:id/status', auth, body, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const st = STATUSES.includes(req.body.status) ? req.body.status : null;
    if (!id || !st) return res.redirect('/admin/issues/' + id + '#end');
    try {
      if (st === 'open') await pool.query("UPDATE order_issues SET status=$1, decision=NULL, resolved_at=NULL WHERE id=$2", [st, id]);
      else await pool.query("UPDATE order_issues SET status=$1, resolved_at=now() WHERE id=$2", [st, id]);
    } catch (e) {}
    res.redirect('/admin/issues/' + id + '#end');
  });

  // the decision console (also mirrors into the thread + pings the customer)
  router.post('/issues/:id/decide', auth, function (req, res) { upShot.single('shot')(req, res, function () { decide(req, res); }); });
  async function decide(req, res) {
    const id = parseInt(req.params.id, 10) || 0;
    const action = String(req.body.action || '');
    const response = String(req.body.response || '').trim().slice(0, 2000);
    const creds = String(req.body.credentials || '').trim();
    const shot = (req.file && req.file.filename) ? req.file.filename : null;
    let flash = 'Updated', threadBody = response || '';
    const go = () => res.redirect('/admin/issues/' + id + '?ok=' + encodeURIComponent(flash) + '#end');
    if (!id || !action) { flash = 'No change'; return go(); }
    try {
      const i = (await pool.query("SELECT i.*, o.id AS oid FROM order_issues i LEFT JOIN orders o ON o.id=i.order_id WHERE i.id=$1", [id])).rows[0];
      if (!i) { flash = 'No change'; return go(); }

      if (action === 'open') {
        await pool.query("UPDATE order_issues SET status='open', decision=NULL, resolved_at=NULL WHERE id=$1", [id]);
        flash = 'Reopened'; threadBody = '';

      } else if (action === 'reject') {
        await pool.query("UPDATE order_issues SET status='rejected', decision='reject', admin_response=$2, admin_screenshot=COALESCE($3,admin_screenshot), resolved_at=now() WHERE id=$1", [id, response || null, shot]);
        flash = 'Declined'; threadBody = response || 'This request was declined.';

      } else if (action === 'fix') {
        await pool.query("UPDATE order_issues SET status='resolved', decision='fix', admin_response=$2, admin_screenshot=COALESCE($3,admin_screenshot), resolved_at=now() WHERE id=$1", [id, response || null, shot]);
        flash = 'Fixed & responded'; threadBody = response || 'Marked as fixed.';

      } else if (action === 'manual') {
        if (!creds) { flash = 'Enter the new credentials for a manual replacement'; return go(); }
        await pool.query("UPDATE order_issues SET status='replaced', decision='manual', replacement_credentials=$2, admin_response=$3, admin_screenshot=COALESCE($4,admin_screenshot), resolved_at=now() WHERE id=$1", [id, creds, response || null, shot]);
        if (i.oid) await pool.query("UPDATE orders SET delivered_credentials=$2 WHERE id=$1", [i.oid, creds]);
        flash = 'Replaced (manual)'; threadBody = (response ? response + '\n\n' : '') + 'Replacement sent — your new access:\n' + creds;

      } else if (action === 'stock') {
        let pid = null, pick = null;
        if (i.oid) { const pr = await pool.query("SELECT pp.id FROM product_plans pp JOIN orders o ON o.product_id=pp.product_id AND o.plan_label=pp.label WHERE o.id=$1 LIMIT 1", [i.oid]); pid = pr.rows[0] && pr.rows[0].id; }
        if (pid) { const pk = await pool.query("SELECT id, payload FROM inventory_items WHERE plan_id=$1 AND status='available' ORDER BY id ASC LIMIT 1", [pid]); pick = pk.rows[0]; }
        if (!pick) { flash = 'No stock available — use Manual replacement'; return go(); }
        await pool.query("UPDATE inventory_items SET status='used', order_no=$2, delivered_at=now() WHERE id=$1", [pick.id, i.order_no || null]);
        await pool.query("UPDATE order_issues SET status='replaced', decision='stock', replacement_credentials=$2, admin_response=$3, admin_screenshot=COALESCE($4,admin_screenshot), resolved_at=now() WHERE id=$1", [id, pick.payload, response || null, shot]);
        if (i.oid) await pool.query("UPDATE orders SET delivered_credentials=$2 WHERE id=$1", [i.oid, pick.payload]);
        flash = 'Replaced from stock'; threadBody = (response ? response + '\n\n' : '') + 'Replacement sent — your new access:\n' + pick.payload;

      } else { flash = 'No change'; return go(); }

      if (threadBody || shot) { await addMsg(id, 'admin', threadBody, shot); }
      if (action === 'stock' || action === 'manual' || action === 'fix' || action === 'reject') { await pingCustomer(i, threadBody || flash); }
    } catch (e) { flash = 'Error — not saved'; }
    go();
  }

  return router;
};
