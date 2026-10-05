#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON — STEP 25: live pay-accounts + auto verify-claim
#  - Checkout shows the BOT's live receiving accounts (meezan/nayapay/binance)
#    filtered by region — the exact accounts its verifier monitors. Falls back
#    to the site's own payment_methods if the bot is unreachable.
#  - On order placement to a bot account, the site calls verify-claim with the
#    right method + currency (PKR vs USDT) + SHA-256 screenshot hash, and sets
#    the order status: paid / verifying / review / rejected.
#  - Order page is status-aware (auto-refresh while verifying, re-check button,
#    delivered-credentials block ready for Step 26).
#  Files: routes/checkout.js, views/order.ejs. Idempotent + auto-rollback.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -f "$APP/routes/checkout.js" ] || { echo "ABORT: checkout.js not found"; exit 1; }
cd "$APP"
set -a; . "$APP/.env"; set +a
export PGPASSWORD="${DB_PASS:-}"
PSQL="psql -h ${DB_HOST:-127.0.0.1} -p ${DB_PORT:-5432} -U ${DB_USER} -d ${DB_NAME} -X -tAc"

TS=$(date +%s)
BK="$APP/.bak-step25-$TS"; mkdir -p "$BK"
cp routes/checkout.js "$BK/checkout.js"
cp views/order.ejs "$BK/order.ejs"
restore(){ echo "!! ROLLBACK"; cp "$BK/checkout.js" "$APP/routes/checkout.js" 2>/dev/null||true; cp "$BK/order.ejs" "$APP/views/order.ejs" 2>/dev/null||true; pm2 restart gsz >/dev/null 2>&1||true; }
trap 'restore' ERR

echo "== Galaxy Subz x Zayron — Step 25 (pay-accounts + verify-claim) · port ${PORT:-3900} =="

cat > routes/checkout.js <<'EOF_CHECKOUT_JS'
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const express = require('express');
const multer = require('multer');
const botapi = require('../lib/botapi');

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

  // bot pay-account visible in this region?
  function acctVisible(region, a) {
    const r = String(a.region || 'all').toLowerCase();
    if (r === 'all' || r === 'both' || r === '') return true;
    if (region === 'PK') return r === 'pk' || r === 'pakistan';
    return r === 'global' || r === 'intl' || r === 'international' || r === 'world';
  }

  // Payment methods shown at checkout: prefer the bot's live pay-accounts
  // (the exact accounts its verifier monitors); fall back to the site's own.
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

  // ---- place order (+ auto verify-claim for bot accounts) ----
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

      // auto payment verification when paid to a bot-monitored account
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
        } catch (e) {
          await pool.query('UPDATE orders SET claim_result=$1 WHERE id=$2', [('error:' + e.message).slice(0, 80), id]);
        }
      }
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
        } catch (e) { /* leave as-is on bot hiccup */ }
      }
      res.redirect('/order/' + encodeURIComponent(req.params.no));
    } catch (e) { res.redirect('/order/' + encodeURIComponent(req.params.no)); }
  });

  // ---- confirmation / status page ----
  router.get('/order/:no', async (req, res) => {
    try {
      const o = (await pool.query('SELECT * FROM orders WHERE order_no=$1', [req.params.no])).rows[0];
      if (!o) return res.status(404).render('notfound', { what: 'order' });
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
cat > views/order.ejs <<'EOF_ORDER_EJS'
<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<% if (o.status==='verifying') { %><meta http-equiv="refresh" content="12"><% } %>
<title>Order <%= o.order_no %> · Galaxy Subz × Zayron</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Hanken+Grotesk:wght@400;500;600;700&family=Schibsted+Grotesk:wght@600;700;800&display=swap" rel="stylesheet">
<style>
  :root{--bg:#f4f6fc;--ink:#0f1836;--muted:#737e9c;--hair:#e7ebf6;--brand:#2a7bff;--grad:linear-gradient(118deg,#8a2bff,#2a7bff,#17cbf0);--disp:'Schibsted Grotesk',sans-serif}
  *{box-sizing:border-box}body{margin:0;font-family:'Hanken Grotesk',system-ui,sans-serif;background:var(--bg);color:var(--ink)}
  a{color:inherit;text-decoration:none}
  .top{display:flex;align-items:center;gap:12px;padding:16px 20px;max-width:720px;margin:0 auto}
  .top .logo{height:34px}.top b{font-family:var(--disp);font-weight:800;font-size:18px;letter-spacing:-.02em}
  .wrap{max-width:720px;margin:0 auto;padding:8px 20px 70px}
  .card{background:#fff;border-radius:16px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 18px 40px -28px rgba(15,24,54,.3);padding:26px;margin-bottom:18px}
  .ic{width:58px;height:58px;border-radius:50%;display:grid;place-items:center;margin-bottom:16px}
  .ic.ok{background:linear-gradient(135deg,#16b765,#50d48f)}
  .ic.warn{background:linear-gradient(135deg,#f5a623,#ffce6b)}
  .ic.bad{background:linear-gradient(135deg,#e0453f,#ff7a73)}
  .spin{width:54px;height:54px;border-radius:50%;border:4px solid #ffe3a3;border-top-color:#f5a623;animation:sp 1s linear infinite;margin-bottom:16px}
  @keyframes sp{to{transform:rotate(360deg)}}
  h1{font-family:var(--disp);font-size:25px;letter-spacing:-.02em;margin:0 0 4px}
  .lead{color:var(--muted);font-size:14px;margin:0 0 18px;line-height:1.55}
  .ono{font-family:var(--disp);font-weight:800;font-size:20px;letter-spacing:.01em}
  .badge{display:inline-block;font-size:12px;font-weight:700;letter-spacing:.03em;text-transform:uppercase;padding:5px 11px;border-radius:999px}
  .badge.ok{background:#e9fbf1;color:#0b7a42;border:1px solid #bdebd0}
  .badge.warn{background:#fff6e5;color:#9a6700;border:1px solid #ffe3a3}
  .badge.bad{background:#fdeceb;color:#b4322c;border:1px solid #f6c9c4}
  .row{display:flex;justify-content:space-between;font-size:14px;padding:9px 0;border-top:1px solid var(--hair);color:var(--muted)}
  .row:first-of-type{border-top:0}.row b{color:var(--ink);font-weight:600}
  .big{font-family:var(--disp);font-size:20px;font-weight:800}
  .pay{background:#f7f9fe;border:1px solid var(--hair);border-radius:12px;padding:16px;margin-top:8px;font-size:14px;line-height:1.7;white-space:pre-line}
  .pay b{color:var(--ink)}
  .creds{background:#0f1836;color:#eaf0ff;border-radius:12px;padding:16px;margin-top:10px;font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13.5px;line-height:1.6;white-space:pre-wrap;word-break:break-word}
  .btn{display:inline-block;background:var(--grad);color:#fff;font-weight:700;font-size:14.5px;border:0;border-radius:11px;padding:12px 18px;margin-top:6px;cursor:pointer}
  .btn-wa{background:linear-gradient(135deg,#25d366,#0fb858)}
  .btn-ghost{background:#eef2fe;color:#2a3558}
  .fine{font-size:12px;color:var(--muted);margin-top:14px;line-height:1.5}
  .acts{display:flex;flex-wrap:wrap;gap:8px}
</style></head><body>
<div class="top"><a href="/"><img class="logo" src="/static/img/<%= logoFile %>" onerror="this.style.display='none'"><b>Galaxy Subz × Zayron</b></a></div>
<%
  var S=o.status;
  var M={
    pending:{t:'warn',b:'Payment pending',h:'Order placed',m:"We've received your order and are waiting to confirm your payment. Pay to the account below — it then verifies automatically."},
    verifying:{t:'warn',b:'Verifying payment',h:'Verifying your payment',m:"We're matching your payment now — this usually takes a minute. This page refreshes automatically; you can also re-check below."},
    paid:{t:'ok',b:'Payment verified',h:'Payment verified',m:"Thank you! Your payment is confirmed and your order is being prepared. You'll get it on your email and WhatsApp shortly."},
    approved:{t:'ok',b:'Approved',h:'Order approved',m:'Your order is approved and being delivered.'},
    delivered:{t:'ok',b:'Delivered',h:'Your order is ready',m:'Your order has been delivered. Your details are below and were also sent to your email & WhatsApp.'},
    review:{t:'warn',b:'Under review',h:"We're reviewing your payment",m:'Your payment needs a quick manual check. Our team will confirm shortly — message us on WhatsApp with your order number to speed it up.'},
    rejected:{t:'bad',b:'Payment issue',h:"We couldn't verify this payment",m:'This payment could not be matched (it may have already been used). Please contact us on WhatsApp with your order number and proof.'},
    failed:{t:'bad',b:'Failed',h:'Something went wrong',m:"We hit a problem completing this order. Please contact us on WhatsApp — we'll sort it out fast."},
    out_of_stock:{t:'bad',b:'Out of stock',h:'Item went out of stock',m:'This item sold out before we could deliver. Contact us on WhatsApp for a swap or refund.'},
    cancelled:{t:'bad',b:'Cancelled',h:'Order cancelled',m:'This order was cancelled. Contact us on WhatsApp if this is unexpected.'}
  };
  var st=M[S]||M.pending;
  var showPay=(S==='pending'||S==='verifying');
  var waText=encodeURIComponent('Hi! My order '+o.order_no+' ('+o.product_name+' — '+o.plan_label+'). ');
%>
<div class="wrap">
  <div class="card">
    <% if (S==='verifying') { %><div class="spin"></div>
    <% } else { %><div class="ic <%= st.t %>">
      <% if (st.t==='ok') { %><svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
      <% } else if (st.t==='bad') { %><svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>
      <% } else { %><svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M12 8v5l3 2"/><circle cx="12" cy="12" r="9"/></svg><% } %>
    </div><% } %>
    <h1><%= st.h %></h1>
    <p class="lead"><%= st.m %></p>
    <div class="row"><span>Order number</span><span class="ono"><%= o.order_no %></span></div>
    <div class="row"><span>Status</span><span class="badge <%= st.t %>"><%= st.b %></span></div>
    <div class="row"><span><%= o.product_name %></span><b><%= o.plan_label %></b></div>
    <div class="row"><span>Amount</span><span class="big"><%= o.currency==='Rs' ? ('Rs '+Math.round(o.amount_display).toLocaleString('en-US')) : (o.currency+' '+Number(o.amount_display)) %></span></div>
    <div class="row"><span>Payment method</span><b><%= o.method_name %></b></div>
    <% if (o.txn_ref) { %><div class="row"><span>Your reference</span><b><%= o.txn_ref %></b></div><% } %>

    <% if (showPay) { %>
      <form method="post" action="/order/<%= o.order_no %>/reverify" style="margin-top:16px">
        <button class="btn" type="submit">Check payment status</button>
      </form>
    <% } %>
  </div>

  <% if (o.delivered_credentials) { %>
  <div class="card">
    <h1 style="font-size:18px">Your order details</h1>
    <div class="creds"><%= o.delivered_credentials %></div>
    <p class="fine">Keep these safe. A copy has also been sent to your email and WhatsApp.</p>
  </div>
  <% } %>

  <% if (showPay) { %>
  <div class="card">
    <h1 style="font-size:18px">Payment instructions</h1>
    <div class="pay"><b><%= method.name || o.method_name %></b>
<%= method.details || '' %><%= method.instructions ? ('\n'+method.instructions) : '' %></div>
    <p class="fine">Pay the exact amount shown, then (if you haven't) send your proof below. Verification is automatic — this page updates on its own.</p>
    <div class="acts">
      <% if (waNumber) { %>
        <a class="btn btn-wa" target="_blank" rel="noopener" href="https://wa.me/<%= waNumber.replace(/[^0-9]/g,'') %>?text=<%= waText %>">Send proof on WhatsApp</a>
      <% } %>
    </div>
  </div>
  <% } %>

  <div class="card">
    <div class="acts">
      <a class="btn btn-ghost" href="/order/<%= o.order_no %>/invoice" target="_blank">View / print invoice</a>
      <% if (waNumber) { %><a class="btn btn-wa" target="_blank" rel="noopener" href="https://wa.me/<%= waNumber.replace(/[^0-9]/g,'') %>?text=<%= waText %>">Need help? WhatsApp us</a><% } %>
      <a class="btn btn-ghost" href="/">Back to store</a>
    </div>
  </div>
</div>
</body></html>
EOF_ORDER_EJS
echo "[ok] files written"

node --check routes/checkout.js
node <<'EOF_COMPILE'
const ejs=require('ejs'), fs=require('fs');
ejs.compile(fs.readFileSync('views/order.ejs','utf8'), {filename: process.cwd()+'/views/order.ejs'});
console.log('ejs compile ok');
EOF_COMPILE
echo "[ok] syntax + template"

pm2 restart gsz >/dev/null 2>&1 || pm2 start server.js --name gsz >/dev/null 2>&1
sleep 2
BODY="$(curl -fsS "http://127.0.0.1:${PORT:-3900}/" 2>/dev/null || true)"
grep -q "</html>" <<< "$BODY" || { echo "!! health check failed (home page)"; exit 1; }
SLUG="$($PSQL "SELECT slug FROM products WHERE active AND NOT hidden ORDER BY sort,id LIMIT 1" || true)"
if [ -n "$SLUG" ]; then
  CO="$(curl -fsS "http://127.0.0.1:${PORT:-3900}/checkout?p=${SLUG}&plan=0&region=PK" 2>/dev/null || true)"
  grep -q "Payment method" <<< "$CO" || { echo "!! checkout render failed"; exit 1; }
  echo "   checkout renders OK (payment methods present) for: $SLUG"
fi
echo "[ok] site healthy"

trap - ERR
echo "============================================================"
echo "  STEP 25 OK — live pay-accounts + automatic payment verification."
echo "  - Checkout shows the bot's monitored accounts (region-filtered)."
echo "  - Order placement auto-calls verify-claim (method+currency aware)."
echo "  - Statuses: paid / verifying (auto-refresh + re-check) / review / rejected."
echo "  Next: Step 26 = submit-order + poll order-status + deliver credentials."
echo "============================================================"
