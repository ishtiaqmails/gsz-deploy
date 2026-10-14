'use strict';
/* Trial poller — Phase 4b (async). Polls the bot's /api/trial-status for
   'pending' trial_claims (two-step generation), stores credentials when ready,
   and delivers them via the WhatsApp outbox + email. Self-healing: if the
   status GET fails, it re-POSTs generate-trial (idempotent on request_id).
   Never crashes the app.

   Delivery is MASKED in our own premium per-type format via lib/deliveryMsg:
   when structured `fields` are present (from the bot) the trial is composed
   exactly like a paid order (IPTV -> Your line + DNS + Watch on players);
   when fields are absent it falls back to the whatsapp.trial_ready template. */
const botapi = require('./botapi');
const deliveryMsg = require('./deliveryMsg');
let mailer = null; try { mailer = require('./mailer'); } catch (e) { mailer = { configured: () => false, send: async () => ({}) }; }

module.exports = function (pool) {
  const wanotify = require('./wanotify')(pool);
  async function setting(k) { const r = await pool.query('SELECT value FROM wa_settings WHERE key=$1', [k]); return r.rows[0] ? r.rows[0].value : ''; }

  async function deliver(t) {
    try {
      const base = (await setting('site_base_url')) || '';
      const link = base ? (base.replace(/\/+$/, '') + '/?tool=trials') : '/?tool=trials';
      // UNIQUE_TRIAL_IDEMPOTENCY_v1: key off the globally-unique bot_ref (TRIAL-<id>-<hex>),
      // not the claim id — so a reused id (after a reset/clear) can never collide with an
      // old outbox row and get silently suppressed as "already sent".
      const idk = 'trial-' + (t.bot_ref || t.id);
      const dl = t.duration_label || (t.duration_hours ? (t.duration_hours + ' Hours') : 'Trial');

      // Prefer structured fields (bot's trial-status, else order-status by ref) so we mask in
      // our own premium format instead of dumping the raw credentials blob.
      let fields = (t && t.fields && t.fields.delivery_type) ? t.fields : null;
      if (!fields && botapi.orderStatus && t.bot_ref) {
        try { const os = await botapi.orderStatus(t.bot_ref); if (os && os.fields && os.fields.delivery_type) fields = os.fields; } catch (e2) {}
      }

      if (fields) {
        const sales = (await setting('wa_sales_number')) || (await setting('wa_support_number')) || '';
        const site = (await setting('site_name')) || 'Galaxy Subz × Zayron';
        const siteUrl = base ? base.replace(/\/+$/, '') : '';
        const msg = deliveryMsg.compose(
          { product_name: t.server_name || t.trial_type, plan_label: dl, created_at: Date.now() },
          fields,
          { siteName: site, salesNumber: sales, trial: true, durationLabel: dl, siteUrl: siteUrl }
        );
        if (msg && msg.main) {
          await wanotify.enqueue({
            customer_id: t.customer_id, destination_identity_id: t.whatsapp_identity_id,
            template_key: 'whatsapp.raw', vars: { body: msg.main }, idempotency_key: idk
          });
          return;
        }
      }

      // Fallback: no structured fields -> premium trial_ready template (raw credentials inside).
      await wanotify.enqueue({
        customer_id: t.customer_id, destination_identity_id: t.whatsapp_identity_id, template_key: 'whatsapp.trial_ready',
        vars: { server_name: t.server_name || t.trial_type, duration_label: dl, secure_link: link, credentials: String(t.credentials || '') },
        idempotency_key: idk
      });
    } catch (e) {}
    // Email delivery intentionally disabled — trials are delivered via WhatsApp only.
  }

  async function tick() {
    if (!(botapi.configured && botapi.configured())) return;
    let rows = [];
    try {
      rows = (await pool.query(
        `SELECT tc.id, tc.customer_id, tc.whatsapp_identity_id, tc.trial_type, tc.server_name, tc.duration_hours, tc.bot_ref,
                c.email, c.ref_code, ts.duration_label
         FROM trial_claims tc JOIN customers c ON c.id=tc.customer_id
         LEFT JOIN trial_servers ts ON ts.sku=tc.trial_type
         WHERE tc.status='pending' AND tc.bot_ref IS NOT NULL AND tc.claimed_at > now() - interval '20 minutes'
         ORDER BY tc.id LIMIT 10`)).rows;
    } catch (e) { return; }
    for (const t of rows) {
      try {
        let st = null;
        try { st = await botapi.trialStatus(t.bot_ref); } catch (e) { st = null; }
        if (!st || typeof st.status === 'undefined') {
          // status unreachable — re-request (idempotent on request_id), try again next tick
          try { await botapi.generateTrial({ sku: t.trial_type, hours: t.duration_hours || 24, customer_ref: t.ref_code || '', request_id: t.bot_ref }); } catch (e) {}
          continue;
        }
        if (st.status === 'done' && st.credentials) {
          const exp = st.expires_at ? new Date(st.expires_at) : (t.duration_hours ? new Date(Date.now() + t.duration_hours * 3600 * 1000) : null);
          await pool.query("UPDATE trial_claims SET status='active', credentials=$1, expires_at=$2, bot_ref=$3 WHERE id=$4 AND status='pending'",
            [String(st.credentials), exp, String(st.trial_ref || t.bot_ref), t.id]);
          await deliver(Object.assign({}, t, { credentials: st.credentials, fields: st.fields || null }));
        } else if (st.status === 'failed') {
          await pool.query("UPDATE trial_claims SET status='failed', bot_ref=$1 WHERE id=$2 AND status='pending'", [String(st.error || 'failed').slice(0, 140), t.id]);
        }
        // 'pending' -> leave for next tick
      } catch (e) { /* skip this one */ }
    }
  }

  function startWorker() {
    const iv = parseInt(process.env.TRIAL_POLL_MS || '5000', 10);
    setInterval(() => { tick().catch(() => {}); }, iv);
    console.log('[trialpoll] worker started (every ' + iv + 'ms)');
  }

  return { startWorker, tick };
};
