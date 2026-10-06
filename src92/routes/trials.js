'use strict';
/* Trials — Phase 4b: public /trials page, the claim flow (verified account +
   LID-based quota), and the customer's /account/trials view. Generation goes
   through botapi.generateTrial (graceful: a trial sits 'pending' until the bot
   endpoint exists, then the claim delivers credentials + WhatsApp + email).
   Quota is race-safe via a per-(identity,server) advisory lock. */
const express = require('express');
const storefront = require('../lib/storefront');
const botapi = require('../lib/botapi');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '64kb' });

  function requireLogin(req, res, next) {
    if (req.session && req.session.customer) return next();
    return res.redirect('/login?next=' + encodeURIComponent(req.originalUrl || '/trials'));
  }
  const reqIp = req => String(req.headers['x-forwarded-for'] || req.ip || '').split(',')[0].trim();

  async function shell() {
    const cats = await storefront.loadCats(pool);
    const s = await storefront.loadSettings(pool);
    const products = await storefront.loadProducts(pool);
    const waNumber = s.wa_number || process.env.WA_NUMBER || '';
    return { cats, settings: s, waNumber, siteName: s.site_name || 'Galaxy Subz × Zayron', logoFile: s.logo_file || 'logo.png', shellJson: storefront.shellJson(cats, products, s, waNumber) };
  }
  async function custVerified(custId) {
    const c = (await pool.query('SELECT email_verified, ref_code, email FROM customers WHERE id=$1', [custId])).rows[0] || {};
    const link = (await pool.query("SELECT whatsapp_identity_id FROM customer_whatsapp_links WHERE customer_id=$1 AND status='ACTIVE' AND is_primary=true LIMIT 1", [custId])).rows[0];
    return { emailOk: !!c.email_verified, waOk: !!link, identityId: link ? link.whatsapp_identity_id : null, ref: c.ref_code || '', email: c.email || '' };
  }

  // ---- public trials page ----
  router.get('/trials', async (req, res) => {
    const servers = (await pool.query("SELECT sku, name, duration_label, duration_hours, max_per_customer FROM trial_servers WHERE enabled=true ORDER BY name")).rows;
    let me = null, used = {};
    if (req.session && req.session.customer) {
      me = await custVerified(req.session.customer.id);
      if (me.identityId) {
        (await pool.query("SELECT trial_type, count(*)::int n FROM trial_claims WHERE whatsapp_identity_id=$1 AND status<>'rejected' GROUP BY trial_type", [me.identityId])).rows.forEach(r => used[r.trial_type] = r.n);
      }
    }
    res.render('trials', Object.assign(await shell(), { title: 'Free IPTV Trials', servers, me, used, flash: req.query.msg || null }));
  });

  // ---- claim ----
  router.post('/trials/claim', body, requireLogin, async (req, res) => {
    const cust = req.session.customer; const sku = (req.body.sku || '').trim();
    const back = m => res.redirect('/trials?msg=' + encodeURIComponent(m));
    const srv = (await pool.query("SELECT * FROM trial_servers WHERE sku=$1 AND enabled=true", [sku])).rows[0];
    if (!srv) return back('That trial is not available right now.');
    const v = await custVerified(cust.id);
    if (!v.emailOk) return res.redirect('/account/verify-email');
    if (!v.waOk) return res.redirect('/account/whatsapp');

    // quota — race-safe per (identity, server)
    const c = await pool.connect();
    let claimId = null, over = false;
    try {
      await c.query('BEGIN');
      await c.query('SELECT pg_advisory_xact_lock(hashtext($1))', ['trial:' + v.identityId + ':' + sku]);
      const n = (await c.query("SELECT count(*)::int n FROM trial_claims WHERE whatsapp_identity_id=$1 AND trial_type=$2 AND status<>'rejected'", [v.identityId, sku])).rows[0].n;
      if (n >= srv.max_per_customer) { over = true; await c.query('ROLLBACK'); }
      else {
        const r = await c.query(
          "INSERT INTO trial_claims(customer_id,whatsapp_identity_id,trial_type,status,ip,server_name,duration_hours) VALUES($1,$2,$3,'pending',$4,$5,$6) RETURNING id",
          [cust.id, v.identityId, sku, reqIp(req), srv.name, srv.duration_hours]);
        claimId = r.rows[0].id; await c.query('COMMIT');
      }
    } catch (e) { try { await c.query('ROLLBACK'); } catch (_) {} return back('Something went wrong. Please try again.'); }
    finally { c.release(); }
    if (over) return back('You have already used all your free trials for ' + srv.name + '.');

    // Request generation (async two-step). Store the request_id; the trial
    // poller GETs /api/trial-status, then delivers credentials when ready.
    const ref = 'TRIAL-' + claimId;
    await pool.query("UPDATE trial_claims SET bot_ref=$1 WHERE id=$2", [ref, claimId]);
    try { if (botapi.configured && botapi.configured()) await botapi.generateTrial({ sku, hours: srv.duration_hours, customer_ref: v.ref, request_id: ref }); } catch (e) {}
    return back('Your ' + srv.name + ' trial is being prepared — we’ll send it to your WhatsApp and show it under My trials shortly.');
  });

  // ---- customer's trials ----
  router.get('/account/trials', requireLogin, async (req, res) => {
    const rows = (await pool.query(
      "SELECT id, trial_type, server_name, status, credentials, expires_at, duration_hours, claimed_at FROM trial_claims WHERE customer_id=$1 ORDER BY id DESC LIMIT 30",
      [req.session.customer.id])).rows;
    res.render('account/trials', Object.assign(await shell(), { title: 'My trials', rows }));
  });

  return router;
};
