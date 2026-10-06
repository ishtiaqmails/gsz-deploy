'use strict';
/* Trials — Phase 4b: public /trials page, the claim flow (verified account +
   LID-based quota), and the customer's /account/trials view. Generation goes
   through botapi.generateTrial (graceful: a trial sits 'pending' until the bot
   endpoint exists, then the claim delivers credentials + WhatsApp + email).
   Quota is race-safe via a per-(identity,server) advisory lock. */
const express = require('express');
const storefront = require('../lib/storefront');
const botapi = require('../lib/botapi');
let mailer = null; try { mailer = require('../lib/mailer'); } catch (e) { mailer = { configured: () => false, send: async () => ({}) }; }

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '64kb' });
  const wanotify = require('../lib/wanotify')(pool);

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
  async function setting(k) { const r = await pool.query('SELECT value FROM wa_settings WHERE key=$1', [k]); return r.rows[0] ? r.rows[0].value : ''; }

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

    // generate (graceful)
    try {
      if (botapi.configured && botapi.configured()) {
        const ref = 'TRIAL-' + claimId;
        let resp = null;
        try { resp = await botapi.generateTrial({ sku, hours: srv.duration_hours, customer_ref: v.ref, request_id: ref }); } catch (e) { resp = null; }
        const creds = resp && (resp.credentials || resp.creds);
        if (resp && resp.ok && creds) {
          const expires = resp.expires_at ? new Date(resp.expires_at) : new Date(Date.now() + srv.duration_hours * 3600 * 1000);
          await pool.query("UPDATE trial_claims SET status='active', credentials=$1, bot_ref=$2, expires_at=$3 WHERE id=$4", [String(creds), String(resp.trial_ref || ref), expires, claimId]);
          await deliver(cust.id, v.identityId, claimId, srv, v);
          return back('Your ' + srv.name + ' trial is ready — see "My trials" and your WhatsApp.');
        }
        await pool.query("UPDATE trial_claims SET bot_ref=$1 WHERE id=$2", [String((resp && resp.error) || 'pending'), claimId]);
      }
    } catch (e) { /* leave pending */ }
    return back('Your ' + srv.name + ' trial is requested — we’ll deliver it to your WhatsApp shortly.');
  });

  async function deliver(custId, identityId, claimId, srv, v) {
    try {
      const base = (await setting('site_base_url')) || '';
      const link = base ? (base.replace(/\/+$/, '') + '/account/trials') : '/account/trials';
      await wanotify.enqueue({ customer_id: custId, destination_identity_id: identityId, template_key: 'whatsapp.trial_ready',
        vars: { server_name: srv.name, duration_label: srv.duration_label || (srv.duration_hours + 'h'), secure_link: link }, idempotency_key: 'trial-' + claimId });
    } catch (e) {}
    try {
      if (mailer.configured && mailer.configured() && v.email) {
        const row = (await pool.query('SELECT credentials FROM trial_claims WHERE id=$1', [claimId])).rows[0] || {};
        const html = '<div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;border:1px solid #eceef3;border-radius:14px">'
          + '<h2 style="margin:0 0 6px;color:#0f1424">Your ' + srv.name + ' trial is ready</h2>'
          + '<p style="color:#5a6276;font-size:14px">Valid for ' + (srv.duration_label || (srv.duration_hours + ' hours')) + '.</p>'
          + '<pre style="background:#f4f6fb;border-radius:10px;padding:14px;white-space:pre-wrap;word-break:break-word;font-size:13.5px">' + String(row.credentials || '') + '</pre></div>';
        await mailer.send(v.email, 'Your ' + srv.name + ' trial is ready', html);
      }
    } catch (e) {}
  }

  // ---- customer's trials ----
  router.get('/account/trials', requireLogin, async (req, res) => {
    const rows = (await pool.query(
      "SELECT id, trial_type, server_name, status, credentials, expires_at, duration_hours, claimed_at FROM trial_claims WHERE customer_id=$1 ORDER BY id DESC LIMIT 30",
      [req.session.customer.id])).rows;
    res.render('account/trials', Object.assign(await shell(), { title: 'My trials', rows }));
  });

  return router;
};
