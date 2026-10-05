#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON — STEP 27: order emails (confirmation + delivery)
#  - lib/emails.js : email-client-safe templates (table layout, inline CSS,
#    premium light look) — confirmationEmail + deliveryEmail (with account).
#  - lib/mailer.js : nodemailer wrapper reading GSZ_SMTP_* from .env; safe
#    no-op if unconfigured or on any send error (email never blocks an order).
#  - checkout.js hooks: confirmation email on order placement; delivery email
#    (with credentials) the moment an order is delivered (bot or inventory).
#  - .env: GSZ_SMTP_HOST/PORT/USER/PASS/FROM/SECURE (blank — fill to go live).
#  Installs nodemailer. Idempotent + auto-rollback.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -f "$APP/routes/checkout.js" ] || { echo "ABORT: checkout.js not found"; exit 1; }
cd "$APP"
set -a; . "$APP/.env"; set +a

TS=$(date +%s)
BK="$APP/.bak-step27-$TS"; mkdir -p "$BK"
cp routes/checkout.js "$BK/checkout.js"
restore(){ echo "!! ROLLBACK"; cp "$BK/checkout.js" "$APP/routes/checkout.js" 2>/dev/null||true; pm2 restart gsz >/dev/null 2>&1||true; }
trap 'restore' ERR

echo "== Galaxy Subz x Zayron — Step 27 (order emails) · port ${PORT:-3900} =="

# ---- 1) install nodemailer (degrades gracefully if it can't) ----
if node -e "require('nodemailer')" >/dev/null 2>&1; then
  echo "[ok] nodemailer already present"
else
  echo "   installing nodemailer..."
  npm install nodemailer --no-audit --no-fund --silent >/dev/null 2>&1 || echo "   (npm install failed — emails stay off until installed; site unaffected)"
  node -e "require('nodemailer')" >/dev/null 2>&1 && echo "[ok] nodemailer installed" || echo "   [warn] nodemailer not available yet"
fi

# ---- 2) files ----
cat > lib/emails.js <<'EOF_EMAILS'
'use strict';
/* Email-client-safe templates (table layout + inline styles, web-safe fonts).
   Light/white premium look matching the Galaxy Subz x Zayron storefront. */

function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
function money(o) { return o.currency === 'Rs' ? ('Rs ' + Math.round(o.amount_display).toLocaleString('en-US')) : (o.currency + ' ' + Number(o.amount_display)); }

function shell(inner, preheader) {
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="x-apple-disable-message-reformatting"></head>
<body style="margin:0;padding:0;background:#eef1f8;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#0f1836">
<div style="display:none;max-height:0;overflow:hidden;opacity:0">${esc(preheader || '')}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#eef1f8"><tr><td align="center" style="padding:28px 14px">
  <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:600px;max-width:100%;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 18px 50px -30px rgba(15,24,54,.45)">
    <tr><td style="height:6px;background:#8a2bff;background:linear-gradient(90deg,#8a2bff,#2a7bff,#17cbf0);font-size:0;line-height:0">&nbsp;</td></tr>
    <tr><td style="padding:26px 34px 6px">
      <table role="presentation" width="100%"><tr>
        <td style="font-weight:800;font-size:19px;letter-spacing:-.3px;color:#0f1836">Galaxy&nbsp;Subz <span style="color:#8a2bff">×</span> Zayron</td>
        <td align="right" style="font-size:12px;color:#8b93bb;font-weight:700;letter-spacing:.3px;text-transform:uppercase">Digital&nbsp;Subscriptions</td>
      </tr></table>
    </td></tr>
    ${inner}
    <tr><td style="padding:22px 34px 30px;border-top:1px solid #eef1f8">
      <p style="margin:0 0 4px;font-size:12.5px;color:#8b93bb;line-height:1.6">You're receiving this because you placed an order at Galaxy Subz × Zayron.</p>
      <p style="margin:0;font-size:12.5px;color:#8b93bb;line-height:1.6">Need help? Just reply to this email or message us on WhatsApp — we're quick.</p>
    </td></tr>
  </table>
  <div style="font-size:11.5px;color:#9aa2c4;margin-top:16px">© Galaxy Subz × Zayron · galaxyzayron.store</div>
</td></tr></table>
</body></html>`;
}

function btn(href, label, color) {
  return `<a href="${esc(href)}" style="display:inline-block;background:${color};color:#ffffff;text-decoration:none;font-weight:700;font-size:14.5px;padding:12px 22px;border-radius:11px">${esc(label)}</a>`;
}

function rows(o) {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:6px 0 0;font-size:14.5px">
    <tr><td style="padding:9px 0;color:#737e9c;border-top:1px solid #eef1f8">Order number</td><td align="right" style="padding:9px 0;font-weight:800;border-top:1px solid #eef1f8">${esc(o.order_no)}</td></tr>
    <tr><td style="padding:9px 0;color:#737e9c;border-top:1px solid #eef1f8">${esc(o.product_name)}</td><td align="right" style="padding:9px 0;font-weight:700;border-top:1px solid #eef1f8">${esc(o.plan_label)}</td></tr>
    <tr><td style="padding:9px 0;color:#737e9c;border-top:1px solid #eef1f8">Amount</td><td align="right" style="padding:9px 0;font-weight:800;border-top:1px solid #eef1f8">${esc(money(o))}</td></tr>
  </table>`;
}

// 1) DELIVERY email — sent when the order is delivered (contains the account)
function deliveryEmail(o, opts) {
  opts = opts || {};
  const wa = opts.waLink ? `<tr><td align="center" style="padding:6px 34px 2px">${btn(opts.waLink, 'Message us on WhatsApp', '#12b36a')}</td></tr>` : '';
  const orderUrl = opts.orderUrl ? `<tr><td align="center" style="padding:10px 34px 2px">${btn(opts.orderUrl, 'View your order', '#2a7bff')}</td></tr>` : '';
  const inner = `
    <tr><td style="padding:14px 34px 2px">
      <table role="presentation"><tr>
        <td width="46" valign="top"><div style="width:44px;height:44px;border-radius:50%;background:#16b765;background:linear-gradient(135deg,#16b765,#50d48f);text-align:center;line-height:44px;color:#fff;font-size:22px;font-weight:800">&#10003;</div></td>
        <td style="padding-left:12px"><div style="font-size:22px;font-weight:800;letter-spacing:-.4px">Your order is ready</div>
        <div style="font-size:14px;color:#737e9c;margin-top:3px">Thanks for your purchase! Here are your details.</div></td>
      </tr></table>
    </td></tr>
    <tr><td style="padding:16px 34px 0">${rows(o)}</td></tr>
    <tr><td style="padding:18px 34px 0">
      <div style="font-size:12px;font-weight:800;letter-spacing:.4px;text-transform:uppercase;color:#8b93bb;margin:0 0 8px">Your account / access</div>
      <div style="background:#0f1836;color:#eaf0ff;border-radius:12px;padding:16px;font-family:Consolas,Menlo,monospace;font-size:13.5px;line-height:1.7;white-space:pre-wrap;word-break:break-word">${esc(o.delivered_credentials || '')}</div>
      <p style="margin:10px 0 0;font-size:12.5px;color:#8b93bb">Keep these safe. If anything doesn't work, contact us and we'll fix or replace it fast.</p>
    </td></tr>
    ${orderUrl}
    ${wa}
    <tr><td style="height:12px"></td></tr>`;
  return shell(inner, 'Your Galaxy Subz × Zayron order ' + o.order_no + ' is ready.');
}

// 2) CONFIRMATION email — sent when the order is placed / payment received
function confirmationEmail(o, opts) {
  opts = opts || {};
  const verifying = (o.status === 'verifying' || o.status === 'pending');
  const headline = verifying ? 'Order received — verifying payment' : 'Payment confirmed';
  const sub = verifying
    ? "We've got your order and are confirming your payment. You'll get your account by email the moment it's verified — usually within minutes."
    : 'Your payment is confirmed and your order is being prepared. Your account will arrive by email shortly.';
  const orderUrl = opts.orderUrl ? `<tr><td align="center" style="padding:16px 34px 2px">${btn(opts.orderUrl, 'Track your order', '#2a7bff')}</td></tr>` : '';
  const inner = `
    <tr><td style="padding:14px 34px 2px">
      <div style="font-size:22px;font-weight:800;letter-spacing:-.4px">${esc(headline)}</div>
      <div style="font-size:14px;color:#737e9c;margin-top:4px;line-height:1.6">${esc(sub)}</div>
    </td></tr>
    <tr><td style="padding:16px 34px 0">${rows(o)}</td></tr>
    ${orderUrl}
    <tr><td style="height:14px"></td></tr>`;
  return shell(inner, headline + ' · ' + o.order_no);
}

module.exports = { deliveryEmail, confirmationEmail };
EOF_EMAILS
cat > lib/mailer.js <<'EOF_MAILER'
'use strict';
/* Thin nodemailer wrapper. Reads SMTP from env; safe no-op when unconfigured
   or when a send fails — email must never break an order. */
let nodemailer = null; try { nodemailer = require('nodemailer'); } catch (e) { /* installed by step script */ }

function cfg() {
  return {
    host: process.env.GSZ_SMTP_HOST || '',
    port: parseInt(process.env.GSZ_SMTP_PORT || '587', 10),
    user: process.env.GSZ_SMTP_USER || '',
    pass: process.env.GSZ_SMTP_PASS || '',
    from: process.env.GSZ_SMTP_FROM || process.env.GSZ_SMTP_USER || '',
    secure: String(process.env.GSZ_SMTP_SECURE || '').toLowerCase() === 'true'
  };
}
function configured() { const c = cfg(); return !!(nodemailer && c.host && c.user && c.pass); }

let tx = null, txKey = '';
function transport() {
  const c = cfg();
  if (!configured()) return null;
  const key = [c.host, c.port, c.user, c.secure].join('|');
  if (tx && key === txKey) return tx;
  tx = nodemailer.createTransport({ host: c.host, port: c.port, secure: c.secure || c.port === 465, auth: { user: c.user, pass: c.pass } });
  txKey = key;
  return tx;
}

async function send(to, subject, html) {
  try {
    if (!to) return { skipped: true };
    const t = transport();
    if (!t) { console.log('[mailer] not configured; skip ->', to, '|', subject); return { skipped: true }; }
    const c = cfg();
    const info = await t.sendMail({ from: c.from, to, subject, html });
    return { ok: true, id: info && info.messageId };
  } catch (e) { console.log('[mailer] send error:', e.message); return { error: e.message }; }
}

module.exports = { configured, send };
EOF_MAILER
cat > routes/checkout.js <<'EOF_CHECKOUT_JS'
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const express = require('express');
const multer = require('multer');
const botapi = require('../lib/botapi');
const mailer = require('../lib/mailer');
const emails = require('../lib/emails');

module.exports = function (pool) {
  const router = express.Router();
  const UP = path.join(__dirname, '..', 'uploads', 'proofs');
  fs.mkdirSync(UP, { recursive: true });

  const storage = multer.diskStorage({
    destination: (q, f, cb) => cb(null, UP),
    filename: (q, f, cb) => cb(null, 'proof_' + Date.now() + '_' + Math.random().toString(36).slice(2, 8) + path.extname(f.originalname || '').toLowerCase())
  });
  const okf = /\.(jpg|jpeg|png|webp|gif|pdf)$/i;
  const upload = multer({ storage, limits: { fileSize: 12 * 1024 * 1024 }, fileFilter: (q, f, cb) => cb(null, okf.test(f.originalname || '')) });

  const REGIONS = { PK: { cur: 'Rs', rate: 1 }, US: { cur: '$', rate: 0.0036 }, GB: { cur: '£', rate: 0.0028 }, AE: { cur: 'AED', rate: 0.013 } };
  const reg = r => (REGIONS[r] ? r : 'PK');
  function fmt(cur, val) { val = Number(val) || 0; if (cur === 'Rs') return 'Rs ' + Math.round(val).toLocaleString('en-US'); return cur + ' ' + (val < 10 ? val.toFixed(2) : Math.round(val).toLocaleString('en-US')); }
  async function settingsObj() { const s = {}; (await pool.query('SELECT key,value FROM settings')).rows.forEach(r => { s[r.key] = r.value; }); return s; }
  function visible(region, m) { return m.scope === 'all' || (region === 'PK' ? m.scope === 'pk' : m.scope === 'global'); }
  function quote(m, pkr, usd, dispCur, disp) {
    if (m.currency === 'PKR') return fmt('Rs', pkr);
    if (m.currency === 'USD' || m.currency === 'USDT') return fmt('$', usd);
    return fmt(dispCur, disp);
  }
  const usdtAmount = pkr => +(Number(pkr || 0) * REGIONS.US.rate).toFixed(2);

  // -------- email helpers --------
  function siteUrl() { const d = (process.env.SITE_DOMAIN || '').replace(/\/+$/, ''); return d ? (/^https?:/i.test(d) ? d : ('https://' + d)) : ''; }
  async function emailOrder(o, kind) {
    try {
      if (!o || !o.email || !mailer.configured()) return;
      const base = siteUrl();
      const opts = {
        orderUrl: base ? (base + '/order/' + encodeURIComponent(o.order_no)) : '',
        waLink: process.env.WA_NUMBER ? ('https://wa.me/' + String(process.env.WA_NUMBER).replace(/[^0-9]/g, '')) : ''
      };
      let subject, html;
      if (kind === 'delivered') { subject = 'Your order ' + o.order_no + ' is ready'; html = emails.deliveryEmail(o, opts); }
      else { subject = (o.status === 'paid' ? 'Payment confirmed' : 'Order received') + ' · ' + o.order_no; html = emails.confirmationEmail(o, opts); }
      await mailer.send(o.email, subject, html);
    } catch (e) { /* email never blocks an order */ }
  }

  function acctVisible(region, a) {
    const r = String(a.region || 'all').toLowerCase();
    if (r === 'all' || r === 'both' || r === '') return true;
    if (region === 'PK') return r === 'pk' || r === 'pakistan';
    return r === 'global' || r === 'intl' || r === 'international' || r === 'world';
  }

  async function payMethods(region, pkr, usd) {
    if (botapi.configured()) {
      try {
        const accts = await botapi.getPayAccounts();
        if (Array.isArray(accts) && accts.length) {
          const vis = accts.filter(a => acctVisible(region, a));
          const use = vis.length ? vis : accts;
          const list = use.map(a => {
            const isUsd = String(a.currency || '').toUpperCase() !== 'PKR';
            return {
              key: a.key, name: a.label || a.method || a.key, currency: a.currency || 'PKR',
              title: a.title || '', account: a.account || '', instructions: a.instructions || '',
              region: a.region || 'all', botAcct: true,
              pay: isUsd ? (String(a.currency || 'USDT') + ' ' + usdtAmount(pkr)) : fmt('Rs', pkr),
              details: (a.title ? ('Title: ' + a.title) : '') + (a.account ? ('\nAccount: ' + a.account) : '')
            };
          });
          return { methods: list, botAcct: true };
        }
      } catch (e) { /* fall through to site methods */ }
    }
    const R = REGIONS[region];
    const disp = pkr * R.rate;
    const allm = (await pool.query('SELECT key,name,currency,scope,details,instructions FROM payment_methods WHERE active ORDER BY sort,id')).rows;
    const methods = allm.filter(m => visible(region, m)).map(m => Object.assign({}, m, { botAcct: false, title: '', account: '', pay: quote(m, pkr, usd, R.cur, disp) }));
    return { methods, botAcct: false };
  }

  function customerFields(deliveryType) {
    if (['hotplayer', 'ibosol', 'zayron'].includes(deliveryType)) return ['mac'];
    if (deliveryType === 'smm') return ['link', 'qty'];
    return [];
  }

  async function availability(plan, deliveryType) {
    try {
      if (plan.source === 'inventory') {
        const n = (await pool.query("SELECT count(*)::int n FROM inventory_items WHERE plan_id=$1 AND status='available'", [plan.id])).rows[0].n;
        return { available: n > 0, count: n, kind: 'inventory' };
      }
      if (plan.source === 'bot' && deliveryType === 'stock' && plan.bot_sku && botapi.configured()) {
        const s = await botapi.getStock(plan.bot_sku);
        return { available: s.available !== false, count: (s.count != null ? s.count : null), kind: 'bot' };
      }
    } catch (e) {
      return { available: true, count: null, kind: plan.source, unknown: true };
    }
    return { available: true, count: null, kind: plan.source };
  }

  async function botMeta(plan) {
    if (plan.source === 'bot' && plan.bot_sku) {
      const b = (await pool.query('SELECT delivery_type, missing FROM bot_products WHERE sku=$1', [plan.bot_sku])).rows[0];
      if (b) return { deliveryType: b.delivery_type, missing: b.missing };
    }
    return { deliveryType: null, missing: false };
  }

  const STATUS_MAP = { genuine: 'paid', pending: 'verifying', lost_race: 'review', ambiguous: 'review', fraud_consumed: 'rejected' };

  // ============ FULFILMENT (bot / inventory / manual) ============
  async function fulfill(orderId) {
    const o = (await pool.query('SELECT * FROM orders WHERE id=$1', [orderId])).rows[0];
    if (!o || o.status !== 'paid') return;

    if (o.source === 'inventory') {
      const plan = (await pool.query('SELECT id FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort, id LIMIT 1', [o.product_id, o.plan_label])).rows[0];
      if (!plan) { await pool.query("UPDATE orders SET status='failed' WHERE id=$1", [o.id]); return; }
      const got = await pool.query(
        `UPDATE inventory_items SET status='delivered', order_no=$1, delivered_at=now()
         WHERE id = (SELECT id FROM inventory_items WHERE plan_id=$2 AND status='available' ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED)
         RETURNING payload`, [o.order_no, plan.id]);
      if (got.rows[0]) {
        await pool.query("UPDATE orders SET status='delivered', delivered_credentials=$1, delivered_at=now() WHERE id=$2", [got.rows[0].payload, o.id]);
        const full = (await pool.query('SELECT * FROM orders WHERE id=$1', [o.id])).rows[0];
        await emailOrder(full, 'delivered');
      } else {
        await pool.query("UPDATE orders SET status='out_of_stock' WHERE id=$1", [o.id]);
      }
      return;
    }

    if (o.source === 'bot' && o.bot_sku && botapi.configured()) {
      try {
        const fields = Object.assign({ email: o.email }, (o.fields && typeof o.fields === 'object') ? o.fields : {});
        const payload = {
          ref: o.order_no, sku: o.bot_sku, quantity: o.qty || 1,
          userPhone: String(o.whatsapp || '').replace(/[^0-9]/g, ''),
          userName: (String(o.email || '').split('@')[0]) || 'Customer',
          payment: { txid: o.txn_ref || '', amountClaimed: Number(o.amount_claimed || o.amount_pkr || 0) },
          fields
        };
        if (o.bot_plan_key) payload.plan_key = o.bot_plan_key;
        if (o.bot_type) payload.type = o.bot_type;
        const sr = await botapi.submitOrder(payload);
        await pool.query("UPDATE orders SET status='delivering', bot_order_id=$1 WHERE id=$2", [String((sr && sr.order_id) || ''), o.id]);
        await pollOnce(o.order_no);
      } catch (e) {
        await pool.query('UPDATE orders SET claim_result=$1 WHERE id=$2', [('submit_err:' + e.message).slice(0, 80), o.id]);
      }
      return;
    }
    // manual: left as 'paid' for the admin to deliver.
  }

  async function pollOnce(orderNo) {
    const o = (await pool.query('SELECT id, status FROM orders WHERE order_no=$1', [orderNo])).rows[0];
    if (!o || o.status !== 'delivering') return;
    try {
      const st = await botapi.orderStatus(orderNo);
      if (st && st.status === 'delivered') {
        await pool.query("UPDATE orders SET status='delivered', delivered_credentials=$1, delivered_at=now() WHERE id=$2", [st.delivered_credentials || '', o.id]);
        const full = (await pool.query('SELECT * FROM orders WHERE id=$1', [o.id])).rows[0];
        await emailOrder(full, 'delivered');
      } else if (st && (st.status === 'failed' || st.status === 'out_of_stock')) {
        await pool.query('UPDATE orders SET status=$1 WHERE id=$2', [st.status, o.id]);
      }
    } catch (e) { /* transient; drainer retries */ }
  }

  // Background drainer: finish deliveries even if the customer closed the page.
  const drainer = setInterval(async () => {
    try {
      if (!botapi.configured()) return;
      const rows = (await pool.query("SELECT id, order_no, status FROM orders WHERE source='bot' AND status IN ('delivering','paid') ORDER BY id DESC LIMIT 20")).rows;
      for (const r of rows) {
        if (r.status === 'delivering') await pollOnce(r.order_no);
        else await fulfill(r.id);
      }
    } catch (e) { /* ignore */ }
  }, 20000);
  if (drainer.unref) drainer.unref();

  // ---- checkout page ----
  router.get('/checkout', async (req, res) => {
    try {
      const slug = String(req.query.p || '');
      const planIdx = parseInt(req.query.plan, 10) || 0;
      const region = reg(req.query.region);
      const prow = (await pool.query('SELECT id, slug, name FROM products WHERE slug=$1 AND active AND NOT hidden', [slug])).rows[0];
      if (!prow) return res.status(404).render('notfound', { what: 'product' });
      const plans = (await pool.query('SELECT id, label, price_pkr, old_pkr, source, bot_sku, bot_plan_key, bot_type FROM product_plans WHERE product_id=$1 ORDER BY sort, id', [prow.id])).rows;
      if (!plans.length) return res.status(404).render('notfound', { what: 'product' });
      const idx = (planIdx >= 0 && planIdx < plans.length) ? planIdx : 0;
      const plan = plans[idx];
      const pkr = Number(plan.price_pkr || 0);
      const R = REGIONS[region];
      const disp = pkr * R.rate;
      const usd = pkr * REGIONS.US.rate;
      const { methods } = await payMethods(region, pkr, usd);
      const s = await settingsObj();

      const meta = await botMeta(plan);
      const needFields = customerFields(meta.deliveryType);
      const avail = (meta.missing) ? { available: false, count: 0, kind: 'bot' } : await availability(plan, meta.deliveryType);

      res.render('checkout', {
        p: prow, plan, planIdx: idx, region, regionList: Object.keys(REGIONS),
        priceDisplay: fmt(R.cur, disp), priceUsd: fmt('$', usd),
        methods, settings: s, logoFile: s.logo_file || 'logo.png',
        waNumber: s.wa_number || process.env.WA_NUMBER || '',
        needFields, avail, error: req.query.e || null
      });
    } catch (e) { res.status(500).send('Checkout error: ' + e.message); }
  });

  // ---- place order (+ auto verify-claim + fulfilment + emails) ----
  router.post('/checkout', upload.single('proof'), async (req, res) => {
    try {
      const b = req.body || {};
      const slug = String(b.product || '');
      const planIdx = parseInt(b.plan, 10) || 0;
      const region = reg(b.region);
      const email = String(b.email || '').trim();
      const whatsapp = String(b.whatsapp || '').trim();
      const method_key = String(b.method || '').trim();
      const txn = String(b.txn || '').trim().slice(0, 200);
      const note = String(b.note || '').trim().slice(0, 1000);
      const mac = String(b.mac || '').trim().slice(0, 64);
      const link = String(b.link || '').trim().slice(0, 400);
      const qty = String(b.qty || '').trim().slice(0, 32);
      const back = '/checkout?p=' + encodeURIComponent(slug) + '&plan=' + planIdx + '&region=' + region;
      const fail = msg => res.redirect(back + '&e=' + encodeURIComponent(msg));

      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return fail('Please enter a valid email so we can send your order.');
      if (whatsapp.replace(/[^0-9]/g, '').length < 7) return fail('Please enter a valid WhatsApp number.');
      const prow = (await pool.query('SELECT id, name FROM products WHERE slug=$1 AND active AND NOT hidden', [slug])).rows[0];
      if (!prow) return fail('Product not found.');
      const plans = (await pool.query('SELECT id, label, price_pkr, source, bot_sku, bot_plan_key, bot_type FROM product_plans WHERE product_id=$1 ORDER BY sort, id', [prow.id])).rows;
      if (!plans.length) return fail('No plans available for this product.');
      const idx = (planIdx >= 0 && planIdx < plans.length) ? planIdx : 0;
      const plan = plans[idx];

      const pkr = Number(plan.price_pkr || 0);
      const R = REGIONS[region];
      const usd = pkr * REGIONS.US.rate;
      const { methods } = await payMethods(region, pkr, usd);
      const chosen = methods.find(x => x.key === method_key);
      if (!chosen) return fail('Please choose a payment method.');

      const meta = await botMeta(plan);
      const needFields = customerFields(meta.deliveryType);
      if (meta.missing) return fail('This item is currently unavailable. Please contact us on WhatsApp.');
      const avail = await availability(plan, meta.deliveryType);
      if (!avail.available) return fail('Sorry, this plan just went out of stock. Please try another plan or contact us on WhatsApp.');
      if (needFields.includes('mac') && mac.replace(/[^0-9a-fA-F]/g, '').length < 12) return fail('Please enter the device MAC address (e.g. AA:BB:CC:DD:EE:FF).');
      if (needFields.includes('link') && !link) return fail('Please enter the target link for this order.');
      if (needFields.includes('qty') && !/^[0-9]+$/.test(qty)) return fail('Please enter a valid quantity.');

      const fields = {};
      if (mac) fields.mac = mac;
      if (link) fields.link = link;
      if (qty) fields.qty = qty;

      const disp = +(pkr * R.rate).toFixed(2);
      const usdv = +(usd).toFixed(2);
      const proof = req.file ? req.file.filename : null;

      const ins = await pool.query(
        `INSERT INTO orders(status,email,whatsapp,product_id,product_name,plan_label,qty,region,currency,unit_amount,amount_display,amount_pkr,amount_usd,method_key,method_name,txn_ref,proof_file,note,source,bot_sku,bot_plan_key,bot_type,fields)
         VALUES('pending',$1,$2,$3,$4,$5,1,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21) RETURNING id`,
        [email, whatsapp, prow.id, prow.name, plan.label, region, R.cur, disp, disp, pkr, usdv, chosen.key, chosen.name, txn, proof, note,
         plan.source || 'manual', plan.bot_sku || null, plan.bot_plan_key || null, plan.bot_type || null, JSON.stringify(fields)]
      );
      const id = ins.rows[0].id;
      const order_no = 'GSZ-' + (1000 + id);
      await pool.query('UPDATE orders SET order_no=$1 WHERE id=$2', [order_no, id]);

      if (chosen.botAcct && botapi.configured()) {
        const isUsd = String(chosen.currency).toUpperCase() !== 'PKR';
        const amount = isUsd ? usdtAmount(pkr) : pkr;
        let shHash = null;
        if (req.file) { try { shHash = crypto.createHash('sha256').update(fs.readFileSync(req.file.path)).digest('hex'); } catch (e) {} }
        try {
          const vr = await botapi.verifyClaim({ amount, since: Date.now() - 20 * 60 * 1000, ref: order_no, userPhone: whatsapp.replace(/[^0-9]/g, ''), method: chosen.key, screenshotHash: shHash });
          const claim = vr && vr.result;
          const st = STATUS_MAP[claim] || 'pending';
          await pool.query(
            "UPDATE orders SET status=$1, claim_result=$2, amount_claimed=$3, verified_at=CASE WHEN $2='genuine' THEN now() ELSE verified_at END WHERE id=$4",
            [st, claim || null, (claim === 'genuine' ? amount : null), id]
          );
          if (claim === 'genuine') await fulfill(id);
        } catch (e) {
          await pool.query('UPDATE orders SET claim_result=$1 WHERE id=$2', [('error:' + e.message).slice(0, 80), id]);
        }
      }

      // send a confirmation email unless it was already delivered (then the delivery email covers it)
      const finalRow = (await pool.query('SELECT * FROM orders WHERE id=$1', [id])).rows[0];
      if (finalRow && finalRow.status !== 'delivered') await emailOrder(finalRow, 'confirm');

      res.redirect('/order/' + order_no);
    } catch (e) { res.status(500).send('Order error: ' + e.message); }
  });

  // ---- re-check a pending/verifying payment ----
  router.post('/order/:no/reverify', async (req, res) => {
    try {
      const o = (await pool.query('SELECT * FROM orders WHERE order_no=$1', [req.params.no])).rows[0];
      if (!o) return res.redirect('/');
      if (['verifying', 'pending'].includes(o.status) && botapi.configured() && o.method_key) {
        const isUsd = o.method_key === 'binance' || String(o.currency || '').toUpperCase() === 'USDT';
        const amount = isUsd ? Number(o.amount_usd) : Number(o.amount_pkr);
        try {
          const vr = await botapi.verifyClaim({ amount, since: Date.now() - 60 * 60 * 1000, ref: o.order_no, userPhone: String(o.whatsapp || '').replace(/[^0-9]/g, ''), method: o.method_key });
          const claim = vr && vr.result;
          const st = STATUS_MAP[claim] || o.status;
          await pool.query(
            "UPDATE orders SET status=$1, claim_result=$2, amount_claimed=CASE WHEN $2='genuine' THEN $3 ELSE amount_claimed END, verified_at=CASE WHEN $2='genuine' THEN now() ELSE verified_at END WHERE id=$4",
            [st, claim || o.claim_result, amount, o.id]
          );
          if (claim === 'genuine') await fulfill(o.id);
        } catch (e) { /* leave as-is on bot hiccup */ }
      }
      res.redirect('/order/' + encodeURIComponent(req.params.no));
    } catch (e) { res.redirect('/order/' + encodeURIComponent(req.params.no)); }
  });

  // ---- confirmation / status page ----
  router.get('/order/:no', async (req, res) => {
    try {
      let o = (await pool.query('SELECT * FROM orders WHERE order_no=$1', [req.params.no])).rows[0];
      if (!o) return res.status(404).render('notfound', { what: 'order' });
      if (o.status === 'delivering') { await pollOnce(o.order_no); o = (await pool.query('SELECT * FROM orders WHERE order_no=$1', [req.params.no])).rows[0]; }
      let m = null;
      if (botapi.configured()) {
        try { const accts = await botapi.getPayAccounts(); const a = (accts || []).find(x => x.key === o.method_key); if (a) m = { name: a.label || a.method, details: 'Title: ' + a.title + '\nAccount: ' + a.account, instructions: a.instructions || '', currency: a.currency }; } catch (e) {}
      }
      if (!m) m = (await pool.query('SELECT name, details, instructions, currency FROM payment_methods WHERE key=$1', [o.method_key])).rows[0] || {};
      const s = await settingsObj();
      res.render('order', { o, method: m, settings: s, logoFile: s.logo_file || 'logo.png', waNumber: s.wa_number || process.env.WA_NUMBER || '' });
    } catch (e) { res.status(500).send('Order view error: ' + e.message); }
  });

  return router;
};
EOF_CHECKOUT_JS
echo "[ok] files written"

# ---- 3) .env SMTP keys (append only if missing; blank to fill later) ----
add_env(){ grep -q "^$1=" .env || printf '%s=%s\n' "$1" "$2" >> .env; }
grep -q '^GSZ_SMTP_HOST=' .env || printf '\n# --- email (fill to turn on order emails) ---\n' >> .env
add_env GSZ_SMTP_HOST ''
add_env GSZ_SMTP_PORT '587'
add_env GSZ_SMTP_USER ''
add_env GSZ_SMTP_PASS ''
add_env GSZ_SMTP_FROM ''
add_env GSZ_SMTP_SECURE 'false'
echo "[ok] .env SMTP keys present"

# ---- 4) checks ----
node --check lib/emails.js
node --check lib/mailer.js
node --check routes/checkout.js
node <<'EOF_REQ'
require('./lib/emails'); require('./lib/mailer');
const e=require('./lib/emails');
const html=e.deliveryEmail({order_no:'GSZ-1042',product_name:'Opplex TV',plan_label:'6 Months',currency:'Rs',amount_display:750,delivered_credentials:'User: x\nPass: y'},{});
if(!/your order is ready/i.test(html)) { console.error('template check failed'); process.exit(1); }
console.log('templates render ok; mailer configured:', require('./lib/mailer').configured());
EOF_REQ
echo "[ok] syntax + templates"

# ---- 5) restart + health ----
pm2 restart gsz --update-env >/dev/null 2>&1 || pm2 restart gsz >/dev/null 2>&1 || pm2 start server.js --name gsz >/dev/null 2>&1
sleep 2
BODY="$(curl -fsS "http://127.0.0.1:${PORT:-3900}/" 2>/dev/null || true)"
grep -q "</html>" <<< "$BODY" || { echo "!! health check failed (home page)"; exit 1; }
echo "[ok] site healthy"

trap - ERR
echo "============================================================"
echo "  STEP 27 OK — order emails wired in."
echo "  - Confirmation email on order placement."
echo "  - Delivery email (with the account) the moment it's delivered."
echo "  To turn emails ON, set these in /opt/gsz/.env then: pm2 restart gsz --update-env"
echo "     GSZ_SMTP_HOST=   GSZ_SMTP_PORT=587   GSZ_SMTP_USER="
echo "     GSZ_SMTP_PASS=   GSZ_SMTP_FROM=\"Galaxy Subz x Zayron <orders@yourdomain>\""
echo "     GSZ_SMTP_SECURE=false   (true only for port 465)"
echo "  Until set, emails are skipped and orders work normally."
echo "  === BACKEND COMPLETE: catalog -> checkout -> pay -> verify -> deliver -> email ==="
echo "============================================================"
