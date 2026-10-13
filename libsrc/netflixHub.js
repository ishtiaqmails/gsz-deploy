'use strict';
/* Netflix codes for the hub (JSON). Resolves a customer's order -> its active nf_assignment ->
   nf_account credentials, reads the latest codes from the Portal engine (lib/nfMail), and gates
   them by the plan tier (lib/netflixGate). Read-only; owner-checked; fail-safe (never throws). */
const express = require('express');
let gate = null; try { gate = require('../lib/netflixGate'); } catch (e) { gate = null; }
let nfMail = null; try { nfMail = require('../lib/nfMail'); } catch (e) { nfMail = null; }

module.exports = function (pool) {
  const router = express.Router();
  function requireLogin(req, res, next) {
    if (req.session && req.session.customer) return next();
    return res.status(401).json({ ok: false, reason: 'login' });
  }

  router.get('/account/tools/netflix/:no', requireLogin, async (req, res) => {
    try {
      if (!gate) return res.json({ ok: true, isNetflix: false });
      const c = req.session.customer; const no = String(req.params.no || '');
      const o = (await pool.query(
        "SELECT id, order_no, plan_label FROM orders WHERE order_no=$1 AND (customer_id=$2 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($3))) LIMIT 1",
        [no, c.id, c.email])).rows[0];
      if (!o) return res.json({ ok: true, isNetflix: false });
      const a = (await pool.query(
        "SELECT nf_account_id, plan_tier, expires_at FROM nf_assignments WHERE (order_no=$1 OR order_id=$2) AND status='active' ORDER BY id DESC LIMIT 1",
        [o.order_no, o.id])).rows[0];
      if (!a) return res.json({ ok: true, isNetflix: false });
      const acc = (await pool.query("SELECT account_email, credentials FROM nf_accounts WHERE id=$1", [a.nf_account_id])).rows[0];
      let creds = (acc && acc.credentials) || {}; if (typeof creds === 'string') { try { creds = JSON.parse(creds); } catch (e) { creds = {}; } }
      const tier = a.plan_tier || gate.tierForPlan(o.plan_label);
      const expired = !!(a.expires_at && new Date(a.expires_at) < new Date());
      const allowed = gate.PLAN_ALLOW[tier] || gate.PLAN_ALLOW.phone;
      const panel = {
        ok: true, isNetflix: true, tier, expired, allowed,
        account: { email: creds.email || (acc && acc.account_email) || '', password: creds.password || '', profile: creds.profile || '', pin: creds.pin || '' },
        groups: {}, mailOk: false, configured: !!(nfMail && nfMail.configured && nfMail.configured())
      };
      if (acc && panel.configured && !expired) {
        try {
          const r = await nfMail.listForAccount(acc.account_email, req.query.refresh === '1');
          const emails = (r && r.emails) || [];
          const filtered = gate.filterEmails(emails, o.plan_label) || [];
          filtered.forEach(function (e) { const t = e.rtype || 'other'; (panel.groups[t] = panel.groups[t] || []).push({ code: e.code || '', link: e.link || '', subject: e.subject || '', date: e.date || '' }); });
          panel.mailOk = !!(r && r.ok);
        } catch (e) { /* Portal hiccup — show creds + empty sections */ }
      }
      res.json(panel);
    } catch (e) { res.json({ ok: false, isNetflix: false, reason: 'error' }); }
  });

  return router;
};
