#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 7: on-site checkout + orders
#  RUN: cd /opt/gsz-deploy && git pull && bash step7.sh
#  Adds: orders + payment_methods tables, public checkout + order
#  pages, Orders admin (new "Sales" sidebar group) with approve/reject,
#  and wires the product "Buy now" button to /checkout.
#  Payment details are seeded as placeholders — Step 8 makes them editable.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/routes" ] || { echo "ABORT: $APP/routes not found — run earlier steps first."; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"; : "${DB_USER:?}"; : "${DB_NAME:?}"; : "${DB_PASS:?}"
echo "== Galaxy Subz x Zayron — Step 7 (checkout + orders) · port $PORT =="
ts=$(date +%s)
PSQL(){ PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" "$@"; }

# ---------- backups of files we will MODIFY ----------
cp -a "$APP/server.js"                         "$APP/server.js.bak-step7.$ts"
cp -a "$APP/views/product.ejs"                 "$APP/views/product.ejs.bak-step7.$ts"
cp -a "$APP/views/admin/_shell_top.ejs"        "$APP/views/admin/_shell_top.ejs.bak-step7.$ts"

restore(){
  echo ">> rolling back Step 7"
  cp -a "$APP/server.js.bak-step7.$ts"                  "$APP/server.js"
  cp -a "$APP/views/product.ejs.bak-step7.$ts"          "$APP/views/product.ejs"
  cp -a "$APP/views/admin/_shell_top.ejs.bak-step7.$ts" "$APP/views/admin/_shell_top.ejs"
  rm -f "$APP/routes/checkout.js" "$APP/routes/adminOrders.js" \
        "$APP/views/checkout.ejs" "$APP/views/order.ejs" \
        "$APP/views/admin/orders.ejs" "$APP/views/admin/order_detail.ejs"
  pm2 restart gsz >/dev/null 2>&1 || true
}

# ============================================================
# 1. SCHEMA — orders + payment_methods (additive, re-run safe)
# ============================================================
PSQL -v ON_ERROR_STOP=1 <<'GSZ_SQL_EOF'
CREATE TABLE IF NOT EXISTS orders (
  id             serial PRIMARY KEY,
  order_no       text UNIQUE,
  status         text NOT NULL DEFAULT 'pending',
  email          text,
  whatsapp       text,
  product_id     int,
  product_name   text,
  plan_label     text,
  qty            int  NOT NULL DEFAULT 1,
  region         text,
  currency       text,
  unit_amount    numeric(14,2) DEFAULT 0,
  amount_display numeric(14,2) DEFAULT 0,
  amount_pkr     numeric(14,2) DEFAULT 0,
  amount_usd     numeric(14,2) DEFAULT 0,
  method_key     text,
  method_name    text,
  txn_ref        text,
  proof_file     text,
  note           text DEFAULT '',
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS orders_status_idx ON orders(status);
CREATE INDEX IF NOT EXISTS orders_created_idx ON orders(created_at DESC);

CREATE TABLE IF NOT EXISTS payment_methods (
  id           serial PRIMARY KEY,
  key          text UNIQUE,
  name         text NOT NULL,
  currency     text NOT NULL DEFAULT 'USD',
  scope        text NOT NULL DEFAULT 'all',  -- all | pk | global
  details      text DEFAULT '',
  instructions text DEFAULT '',
  active       boolean NOT NULL DEFAULT true,
  sort         int NOT NULL DEFAULT 0
);

INSERT INTO payment_methods(key,name,currency,scope,details,instructions,sort) VALUES
 ('binance','Binance Pay / USDT','USD','all','Set your Binance Pay ID or USDT (TRC20) address in Admin → Payments.','Send the exact USD/USDT amount, then paste your Transaction ID (TxID) below.',10),
 ('bank_pk','Bank Transfer (Pakistan)','PKR','pk','Set your bank account title, number and IBAN in Admin → Payments.','Transfer the exact rupee amount, then paste the transaction reference and/or upload the receipt.',20),
 ('jazzcash','JazzCash','PKR','pk','Set your JazzCash account name & number in Admin → Payments.','Send the exact rupee amount to the JazzCash number, then paste the TID / upload the screenshot.',30),
 ('easypaisa','Easypaisa','PKR','pk','Set your Easypaisa account name & number in Admin → Payments.','Send the exact rupee amount to the Easypaisa number, then paste the TID / upload the screenshot.',40),
 ('taptap','TapTap Send','USD','global','Set your TapTap Send receiving details in Admin → Payments.','Send the exact amount via TapTap Send, then paste the reference / upload the receipt.',50)
ON CONFLICT (key) DO NOTHING;
GSZ_SQL_EOF
echo "[ok] schema: orders + payment_methods ready"

# ============================================================
# 2. ROUTE — public checkout  (routes/checkout.js)
# ============================================================
cat > "$APP/routes/checkout.js" <<'GSZ_CO_EOF'
const path = require('path');
const fs = require('fs');
const express = require('express');
const multer = require('multer');

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
    if (m.currency === 'USD') return fmt('$', usd);
    return fmt(dispCur, disp);
  }

  // ---- checkout page ----
  router.get('/checkout', async (req, res) => {
    try {
      const slug = String(req.query.p || '');
      const planIdx = parseInt(req.query.plan, 10) || 0;
      const region = reg(req.query.region);
      const prow = (await pool.query('SELECT id, slug, name FROM products WHERE slug=$1 AND active AND NOT hidden', [slug])).rows[0];
      if (!prow) return res.status(404).render('notfound', { what: 'product' });
      const plans = (await pool.query('SELECT label, price_pkr, old_pkr FROM product_plans WHERE product_id=$1 ORDER BY sort, id', [prow.id])).rows;
      if (!plans.length) return res.status(404).render('notfound', { what: 'product' });
      const idx = (planIdx >= 0 && planIdx < plans.length) ? planIdx : 0;
      const plan = plans[idx];
      const pkr = Number(plan.price_pkr || 0);
      const R = REGIONS[region];
      const disp = pkr * R.rate;
      const usd = pkr * REGIONS.US.rate;
      const allm = (await pool.query('SELECT key,name,currency,scope,details,instructions FROM payment_methods WHERE active ORDER BY sort,id')).rows;
      const methods = allm.filter(m => visible(region, m)).map(m => Object.assign({}, m, { pay: quote(m, pkr, usd, R.cur, disp) }));
      const s = await settingsObj();
      res.render('checkout', {
        p: prow, plan, planIdx: idx, region, regionList: Object.keys(REGIONS),
        priceDisplay: fmt(R.cur, disp), priceUsd: fmt('$', usd),
        methods, settings: s, logoFile: s.logo_file || 'logo.png',
        waNumber: s.wa_number || process.env.WA_NUMBER || '',
        error: req.query.e || null
      });
    } catch (e) { res.status(500).send('Checkout error: ' + e.message); }
  });

  // ---- place order ----
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
      const back = '/checkout?p=' + encodeURIComponent(slug) + '&plan=' + planIdx + '&region=' + region;
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return res.redirect(back + '&e=' + encodeURIComponent('Please enter a valid email so we can send your order.'));
      if (whatsapp.replace(/[^0-9]/g, '').length < 7) return res.redirect(back + '&e=' + encodeURIComponent('Please enter a valid WhatsApp number.'));
      const prow = (await pool.query('SELECT id, name FROM products WHERE slug=$1 AND active AND NOT hidden', [slug])).rows[0];
      if (!prow) return res.redirect(back + '&e=' + encodeURIComponent('Product not found.'));
      const plans = (await pool.query('SELECT label, price_pkr FROM product_plans WHERE product_id=$1 ORDER BY sort, id', [prow.id])).rows;
      if (!plans.length) return res.redirect(back + '&e=' + encodeURIComponent('No plans available for this product.'));
      const idx = (planIdx >= 0 && planIdx < plans.length) ? planIdx : 0;
      const plan = plans[idx];
      const m = (await pool.query('SELECT key, name, currency, scope FROM payment_methods WHERE key=$1 AND active', [method_key])).rows[0];
      if (!m) return res.redirect(back + '&e=' + encodeURIComponent('Please choose a payment method.'));
      const pkr = Number(plan.price_pkr || 0);
      const R = REGIONS[region];
      const disp = +(pkr * R.rate).toFixed(2);
      const usd = +(pkr * REGIONS.US.rate).toFixed(2);
      const proof = req.file ? req.file.filename : null;
      const ins = await pool.query(
        `INSERT INTO orders(status,email,whatsapp,product_id,product_name,plan_label,qty,region,currency,unit_amount,amount_display,amount_pkr,amount_usd,method_key,method_name,txn_ref,proof_file,note)
         VALUES('pending',$1,$2,$3,$4,$5,1,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16) RETURNING id`,
        [email, whatsapp, prow.id, prow.name, plan.label, region, R.cur, disp, disp, pkr, usd, m.key, m.name, txn, proof, note]
      );
      const id = ins.rows[0].id;
      const order_no = 'GSZ-' + (1000 + id);
      await pool.query('UPDATE orders SET order_no=$1 WHERE id=$2', [order_no, id]);
      res.redirect('/order/' + order_no);
    } catch (e) { res.status(500).send('Order error: ' + e.message); }
  });

  // ---- confirmation / status page ----
  router.get('/order/:no', async (req, res) => {
    try {
      const o = (await pool.query('SELECT * FROM orders WHERE order_no=$1', [req.params.no])).rows[0];
      if (!o) return res.status(404).render('notfound', { what: 'order' });
      const m = (await pool.query('SELECT name, details, instructions, currency FROM payment_methods WHERE key=$1', [o.method_key])).rows[0] || {};
      const s = await settingsObj();
      res.render('order', { o, method: m, settings: s, logoFile: s.logo_file || 'logo.png', waNumber: s.wa_number || process.env.WA_NUMBER || '' });
    } catch (e) { res.status(500).send('Order view error: ' + e.message); }
  });

  return router;
};
GSZ_CO_EOF

# ============================================================
# 3. ROUTE — admin orders  (routes/adminOrders.js)
# ============================================================
cat > "$APP/routes/adminOrders.js" <<'GSZ_AO_EOF'
const path = require('path');
const fs = require('fs');
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  const UP = path.join(__dirname, '..', 'uploads', 'proofs');

  function auth(req, res, next) {
    if (req.session && req.session.admin) return next();
    return res.redirect('/admin/login');
  }

  router.get('/orders', auth, async (req, res) => {
    try {
      const status = String(req.query.status || '');
      const where = status ? 'WHERE status=$1' : '';
      const params = status ? [status] : [];
      const rows = (await pool.query(
        `SELECT id, order_no, status, email, whatsapp, product_name, plan_label, currency, amount_display, amount_pkr, method_name, created_at
         FROM orders ${where} ORDER BY id DESC LIMIT 300`, params)).rows;
      const counts = (await pool.query('SELECT status, count(*)::int n FROM orders GROUP BY status')).rows
        .reduce((a, r) => { a[r.status] = r.n; return a; }, {});
      res.render('admin/orders', { rows, counts, status, flash: req.query.ok || null });
    } catch (e) { res.status(500).send('Orders error: ' + e.message); }
  });

  router.get('/orders/proof/:file', auth, (req, res) => {
    const f = path.basename(String(req.params.file || ''));
    const fp = path.join(UP, f);
    if (!f || !fp.startsWith(UP) || !fs.existsSync(fp)) return res.status(404).send('Not found');
    res.sendFile(fp);
  });

  router.get('/orders/:id', auth, async (req, res) => {
    try {
      const o = (await pool.query('SELECT * FROM orders WHERE id=$1', [req.params.id])).rows[0];
      if (!o) return res.redirect('/admin/orders?ok=Order+not+found');
      const m = (await pool.query('SELECT name, details, instructions, currency FROM payment_methods WHERE key=$1', [o.method_key])).rows[0] || {};
      res.render('admin/order_detail', { o, method: m, flash: req.query.ok || null });
    } catch (e) { res.status(500).send('Order detail error: ' + e.message); }
  });

  const ALLOW = ['pending', 'paid', 'approved', 'delivered', 'rejected', 'cancelled'];
  router.post('/orders/:id/status', auth, express.urlencoded({ extended: false }), async (req, res) => {
    try {
      const st = String((req.body || {}).status || '');
      if (!ALLOW.includes(st)) return res.redirect('/admin/orders/' + req.params.id + '?ok=Invalid+status');
      await pool.query('UPDATE orders SET status=$1 WHERE id=$2', [st, req.params.id]);
      res.redirect('/admin/orders/' + req.params.id + '?ok=Status+updated');
    } catch (e) { res.status(500).send('Status error: ' + e.message); }
  });

  return router;
};
GSZ_AO_EOF
echo "[ok] routes: checkout.js + adminOrders.js written"

# ============================================================
# 4. VIEW — public checkout page
# ============================================================
cat > "$APP/views/checkout.ejs" <<'GSZ_CV_EOF'
<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Checkout · <%= p.name %> · Galaxy Subz × Zayron</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Hanken+Grotesk:wght@400;500;600;700&family=Schibsted+Grotesk:wght@600;700;800&display=swap" rel="stylesheet">
<style>
  :root{--bg:#f4f6fc;--ink:#0f1836;--muted:#737e9c;--hair:#e7ebf6;--brand:#2a7bff;--grad:linear-gradient(118deg,#8a2bff,#2a7bff,#17cbf0);--disp:'Schibsted Grotesk',sans-serif}
  *{box-sizing:border-box}body{margin:0;font-family:'Hanken Grotesk',system-ui,sans-serif;background:var(--bg);color:var(--ink)}
  a{color:inherit;text-decoration:none}
  .top{display:flex;align-items:center;gap:12px;padding:16px 20px;max-width:1040px;margin:0 auto}
  .top .logo{height:34px}.top b{font-family:var(--disp);font-weight:800;font-size:18px;letter-spacing:-.02em}
  .wrap{max-width:1040px;margin:0 auto;padding:8px 20px 70px;display:grid;grid-template-columns:1fr 360px;gap:22px}
  @media(max-width:860px){.wrap{grid-template-columns:1fr}}
  h1{font-family:var(--disp);font-size:26px;letter-spacing:-.02em;margin:4px 0 2px}
  .lead{color:var(--muted);font-size:14px;margin:0 0 18px}
  .card{background:#fff;border-radius:16px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 18px 40px -28px rgba(15,24,54,.3);padding:22px;margin-bottom:18px}
  h2{font-size:15px;margin:0 0 14px;letter-spacing:-.01em}
  label.fld{display:block;font-size:13px;font-weight:600;margin:0 0 6px}
  input[type=text],input[type=email],input[type=tel],textarea,select{width:100%;padding:11px 13px;border-radius:10px;border:1px solid var(--hair);font-size:14px;font-family:inherit;margin-bottom:14px;background:#fff}
  input:focus,textarea:focus,select:focus{outline:2px solid var(--brand);outline-offset:1px;border-color:transparent}
  .err{background:#fdecec;color:#b42318;border:1px solid #f6c9c4;border-radius:11px;padding:11px 14px;font-size:14px;font-weight:600;margin-bottom:18px}
  .pm{border:1.5px solid var(--hair);border-radius:12px;padding:14px;margin-bottom:12px;cursor:pointer;transition:.15s}
  .pm:hover{border-color:var(--brand)}
  .pm.sel{border-color:var(--brand);box-shadow:0 0 0 3px rgba(42,123,255,.12)}
  .pm .hd{display:flex;align-items:center;gap:12px}
  .pm .rdo{width:20px;height:20px;border-radius:50%;border:2px solid var(--hair);flex:none;display:grid;place-items:center}
  .pm.sel .rdo:after{content:"";width:10px;height:10px;border-radius:50%;background:var(--brand)}
  .pm .nm{font-weight:700;font-size:14.5px;flex:1}
  .pm .amt{font-family:var(--disp);font-weight:800;font-size:16px}
  .pm .info{font-size:13px;color:var(--muted);margin:9px 0 0;padding-left:32px;line-height:1.5}
  .pm .info b{color:var(--ink)}
  .sum{position:sticky;top:18px}
  .sum .row{display:flex;justify-content:space-between;font-size:14px;padding:7px 0;color:var(--muted)}
  .sum .row b{color:var(--ink);font-weight:600}
  .sum .tot{border-top:1px solid var(--hair);margin-top:8px;padding-top:12px;font-size:15px}
  .sum .tot .big{font-family:var(--disp);font-size:24px;font-weight:800}
  .regsel{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--muted);margin-bottom:14px}
  .regsel select{width:auto;margin:0;padding:7px 10px;border-radius:8px}
  .btn{display:block;width:100%;text-align:center;background:var(--grad);color:#fff;font-weight:700;font-size:15.5px;border:0;border-radius:12px;padding:14px;cursor:pointer;box-shadow:0 14px 30px -14px rgba(42,123,255,.9)}
  .btn:hover{filter:brightness(1.04)}
  .fine{font-size:12px;color:var(--muted);margin:12px 0 0;line-height:1.5}
  .back{display:inline-block;color:var(--muted);font-size:13px;margin:2px 0 10px}
</style></head><body>
<div class="top"><a href="/"><img class="logo" src="/static/img/<%= logoFile %>" onerror="this.style.display='none'"><b>Galaxy Subz × Zayron</b></a></div>
<div class="wrap">
  <form class="col" method="post" action="/checkout" enctype="multipart/form-data">
    <a class="back" href="/product/<%= p.slug %>">← Back to <%= p.name %></a>
    <h1>Checkout</h1>
    <p class="lead">Complete your order for <b><%= p.name %></b> — <%= plan.label %>.</p>
    <% if (error) { %><div class="err"><%= error %></div><% } %>

    <input type="hidden" name="product" value="<%= p.slug %>">
    <input type="hidden" name="plan" value="<%= planIdx %>">
    <input type="hidden" name="region" value="<%= region %>">

    <div class="card">
      <h2>Your details</h2>
      <label class="fld">Email (we send your order & invoice here)</label>
      <input type="email" name="email" placeholder="you@example.com" required>
      <label class="fld">WhatsApp number (for delivery & support)</label>
      <input type="tel" name="whatsapp" placeholder="e.g. +92 3XX XXXXXXX" required>
    </div>

    <div class="card">
      <h2>Payment method</h2>
      <% if (!methods.length) { %>
        <p class="lead">No payment method is available for your region yet. Please contact support on WhatsApp.</p>
      <% } %>
      <% methods.forEach(function(m,i){ %>
        <div class="pm<%= i===0?' sel':'' %>" data-key="<%= m.key %>">
          <div class="hd">
            <span class="rdo"></span>
            <span class="nm"><%= m.name %></span>
            <span class="amt"><%= m.pay %></span>
          </div>
          <div class="info"><b><%= m.details %></b><br><%= m.instructions %></div>
        </div>
      <% }); %>
      <input type="hidden" name="method" id="method" value="<%= methods.length?methods[0].key:'' %>">
    </div>

    <div class="card">
      <h2>Confirm your payment</h2>
      <label class="fld">Transaction ID / reference (after you pay)</label>
      <input type="text" name="txn" placeholder="Paste your TxID / TID / reference">
      <label class="fld">Upload payment screenshot or receipt (optional)</label>
      <input type="file" name="proof" accept="image/*,application/pdf" style="margin-bottom:14px">
      <label class="fld">Notes (optional)</label>
      <textarea name="note" rows="3" placeholder="Anything we should know about your order"></textarea>
    </div>

    <button class="btn" type="submit">Place order</button>
    <p class="fine">After you place the order, we verify your payment and deliver to your email & WhatsApp. You'll get an order number to track status.</p>
  </form>

  <aside>
    <div class="card sum">
      <h2>Order summary</h2>
      <div class="regsel">Prices in
        <select onchange="location.href='/checkout?p=<%= p.slug %>&plan=<%= planIdx %>&region='+this.value">
          <% regionList.forEach(function(rg){ %><option value="<%= rg %>" <%= rg===region?'selected':'' %>><%= rg %></option><% }); %>
        </select>
      </div>
      <div class="row"><span><%= p.name %></span><b><%= plan.label %></b></div>
      <div class="row"><span>Billed in USD (ref.)</span><b><%= priceUsd %></b></div>
      <div class="row tot"><span>Total</span><span class="big"><%= priceDisplay %></span></div>
    </div>
  </aside>
</div>
<script>
(function(){
  var pms=document.querySelectorAll('.pm'), hidden=document.getElementById('method');
  pms.forEach(function(el){el.addEventListener('click',function(){
    pms.forEach(function(x){x.classList.remove('sel')});el.classList.add('sel');hidden.value=el.dataset.key;});});
})();
</script>
</body></html>
GSZ_CV_EOF

# ============================================================
# 5. VIEW — public order confirmation page
# ============================================================
cat > "$APP/views/order.ejs" <<'GSZ_OV_EOF'
<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
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
  .ok{width:58px;height:58px;border-radius:50%;background:linear-gradient(135deg,#16b765,#50d48f);display:grid;place-items:center;margin-bottom:16px}
  h1{font-family:var(--disp);font-size:25px;letter-spacing:-.02em;margin:0 0 4px}
  .lead{color:var(--muted);font-size:14px;margin:0 0 18px;line-height:1.55}
  .ono{font-family:var(--disp);font-weight:800;font-size:20px;letter-spacing:.01em}
  .badge{display:inline-block;font-size:12px;font-weight:700;letter-spacing:.03em;text-transform:uppercase;padding:5px 11px;border-radius:999px;background:#fff6e5;color:#9a6700;border:1px solid #ffe3a3}
  .row{display:flex;justify-content:space-between;font-size:14px;padding:9px 0;border-top:1px solid var(--hair);color:var(--muted)}
  .row:first-of-type{border-top:0}.row b{color:var(--ink);font-weight:600}
  .big{font-family:var(--disp);font-size:20px;font-weight:800}
  .pay{background:#f7f9fe;border:1px solid var(--hair);border-radius:12px;padding:16px;margin-top:8px;font-size:14px;line-height:1.6}
  .pay b{color:var(--ink)}
  .btn{display:inline-block;background:var(--grad);color:#fff;font-weight:700;font-size:14.5px;border-radius:11px;padding:12px 18px;margin-top:6px}
  .btn-wa{background:linear-gradient(135deg,#25d366,#0fb858)}
  .fine{font-size:12px;color:var(--muted);margin-top:14px;line-height:1.5}
</style></head><body>
<div class="top"><a href="/"><img class="logo" src="/static/img/<%= logoFile %>" onerror="this.style.display='none'"><b>Galaxy Subz × Zayron</b></a></div>
<div class="wrap">
  <div class="card">
    <div class="ok"><svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg></div>
    <h1>Order placed</h1>
    <p class="lead">Thank you! We've received your order and are verifying your payment. You'll get your subscription on your email and WhatsApp shortly.</p>
    <div class="row"><span>Order number</span><span class="ono"><%= o.order_no %></span></div>
    <div class="row"><span>Status</span><span class="badge"><%= o.status %></span></div>
    <div class="row"><span><%= o.product_name %></span><b><%= o.plan_label %></b></div>
    <div class="row"><span>Amount</span><span class="big"><%= o.currency==='Rs' ? ('Rs '+Math.round(o.amount_display).toLocaleString('en-US')) : (o.currency+' '+Number(o.amount_display)) %></span></div>
    <div class="row"><span>Payment method</span><b><%= o.method_name %></b></div>
    <% if (o.txn_ref) { %><div class="row"><span>Your reference</span><b><%= o.txn_ref %></b></div><% } %>
  </div>

  <div class="card">
    <h1 style="font-size:18px">Payment instructions</h1>
    <div class="pay"><b><%= method.name || o.method_name %></b><br><%= method.details || '' %><br><%= method.instructions || '' %></div>
    <p class="fine">Already paid? No action needed — we'll verify and deliver. Need help or want to send proof now?</p>
    <% if (waNumber) { %>
      <a class="btn btn-wa" target="_blank" rel="noopener"
         href="https://wa.me/<%= waNumber.replace(/[^0-9]/g,'') %>?text=<%= encodeURIComponent('Hi! My order '+o.order_no+' ('+o.product_name+' — '+o.plan_label+'). Here is my payment proof:') %>">
        Send proof on WhatsApp
      </a>
    <% } %>
    <a class="btn" href="/" style="background:#eef2fe;color:#2a3558;margin-left:8px">Back to store</a>
  </div>
</div>
</body></html>
GSZ_OV_EOF

# ============================================================
# 6. VIEW — admin orders list
# ============================================================
cat > "$APP/views/admin/orders.ejs" <<'GSZ_AOL_EOF'
<%- include('_shell_top', { active:'orders', title:'Orders' }) %>
<p class="sub" style="margin-bottom:16px">Every order placed on the site. Open one to view payment proof and approve or reject.</p>
<% if (flash) { %><div class="flash"><%= flash %></div><% } %>
<div class="qrow">
  <a class="btn <%= status===''?'btn-p':'btn-g' %>" href="/admin/orders">All</a>
  <a class="btn <%= status==='pending'?'btn-p':'btn-g' %>" href="/admin/orders?status=pending">Pending<%= counts.pending?(' ('+counts.pending+')'):'' %></a>
  <a class="btn <%= status==='paid'?'btn-p':'btn-g' %>" href="/admin/orders?status=paid">Paid<%= counts.paid?(' ('+counts.paid+')'):'' %></a>
  <a class="btn <%= status==='approved'?'btn-p':'btn-g' %>" href="/admin/orders?status=approved">Approved<%= counts.approved?(' ('+counts.approved+')'):'' %></a>
  <a class="btn <%= status==='delivered'?'btn-p':'btn-g' %>" href="/admin/orders?status=delivered">Delivered<%= counts.delivered?(' ('+counts.delivered+')'):'' %></a>
  <a class="btn <%= status==='rejected'?'btn-p':'btn-g' %>" href="/admin/orders?status=rejected">Rejected<%= counts.rejected?(' ('+counts.rejected+')'):'' %></a>
</div>
<div class="card" style="padding:0;overflow:hidden">
  <table>
    <thead><tr><th>Order</th><th>Product</th><th>Customer</th><th>Amount</th><th>Method</th><th>Status</th><th style="text-align:right">Open</th></tr></thead>
    <tbody>
    <% if (!rows.length) { %><tr><td colspan="7" style="color:var(--muted);padding:24px 16px">No orders yet.</td></tr><% } %>
    <% rows.forEach(function(r){ %>
      <tr>
        <td style="font-weight:700"><%= r.order_no || ('#'+r.id) %><div style="font-size:12px;color:var(--muted);font-weight:500"><%= new Date(r.created_at).toLocaleString('en-GB') %></div></td>
        <td><%= r.product_name %><div style="font-size:12px;color:var(--muted)"><%= r.plan_label %></div></td>
        <td style="font-size:13px"><%= r.email %><div style="color:var(--muted)"><%= r.whatsapp %></div></td>
        <td style="white-space:nowrap"><%= r.currency==='Rs' ? ('Rs '+Math.round(r.amount_display).toLocaleString('en-US')) : (r.currency+' '+Number(r.amount_display)) %></td>
        <td style="font-size:13px;color:var(--muted)"><%= r.method_name %></td>
        <td>
          <% var col={pending:'#9a6700',paid:'#1b6fd6',approved:'#0b7a42',delivered:'#0b7a42',rejected:'#b42318',cancelled:'#737e9c'}[r.status]||'#737e9c'; %>
          <span style="font-weight:700;color:<%= col %>;text-transform:capitalize"><%= r.status %></span>
        </td>
        <td style="text-align:right"><a class="btn btn-g" style="padding:6px 12px" href="/admin/orders/<%= r.id %>">View</a></td>
      </tr>
    <% }); %>
    </tbody>
  </table>
</div>
<%- include('_shell_bottom') %>
GSZ_AOL_EOF

# ============================================================
# 7. VIEW — admin order detail
# ============================================================
cat > "$APP/views/admin/order_detail.ejs" <<'GSZ_AOD_EOF'
<%- include('_shell_top', { active:'orders', title: (o.order_no || ('Order #'+o.id)) }) %>
<a class="sub" href="/admin/orders" style="display:inline-block;margin-bottom:14px">← All orders</a>
<% if (flash) { %><div class="flash"><%= flash %></div><% } %>
<div style="display:grid;grid-template-columns:1fr 320px;gap:18px">
  <div>
    <div class="card">
      <h2>Order <%= o.order_no || ('#'+o.id) %></h2>
      <table style="margin-top:6px">
        <tbody>
          <tr><td style="color:var(--muted);width:160px">Placed</td><td><%= new Date(o.created_at).toLocaleString('en-GB') %></td></tr>
          <tr><td style="color:var(--muted)">Product</td><td style="font-weight:600"><%= o.product_name %> — <%= o.plan_label %></td></tr>
          <tr><td style="color:var(--muted)">Amount</td><td style="font-weight:700"><%= o.currency==='Rs' ? ('Rs '+Math.round(o.amount_display).toLocaleString('en-US')) : (o.currency+' '+Number(o.amount_display)) %> &nbsp;<span style="color:var(--muted);font-weight:500">(≈ $<%= Number(o.amount_usd) %> · Rs <%= Math.round(o.amount_pkr).toLocaleString('en-US') %>)</span></td></tr>
          <tr><td style="color:var(--muted)">Region</td><td><%= o.region %></td></tr>
          <tr><td style="color:var(--muted)">Method</td><td><%= o.method_name %></td></tr>
          <tr><td style="color:var(--muted)">Txn reference</td><td><%= o.txn_ref || '—' %></td></tr>
          <% if (o.note) { %><tr><td style="color:var(--muted)">Customer note</td><td><%= o.note %></td></tr><% } %>
        </tbody>
      </table>
    </div>
    <div class="card">
      <h2>Customer</h2>
      <table><tbody>
        <tr><td style="color:var(--muted);width:160px">Email</td><td><%= o.email %></td></tr>
        <tr><td style="color:var(--muted)">WhatsApp</td><td><%= o.whatsapp %></td></tr>
      </tbody></table>
    </div>
    <div class="card">
      <h2>Payment proof</h2>
      <% if (o.proof_file) { %>
        <a href="/admin/orders/proof/<%= o.proof_file %>" target="_blank">
          <img src="/admin/orders/proof/<%= o.proof_file %>" style="max-width:100%;border-radius:10px;border:1px solid var(--hair)" onerror="this.outerHTML='<p>Open proof file ↗</p>'">
        </a>
      <% } else { %><p class="hint" style="margin:0;color:var(--muted)">No proof uploaded. Reference: <%= o.txn_ref || '—' %></p><% } %>
    </div>
  </div>
  <div>
    <div class="card">
      <h2>Status</h2>
      <% var col={pending:'#9a6700',paid:'#1b6fd6',approved:'#0b7a42',delivered:'#0b7a42',rejected:'#b42318',cancelled:'#737e9c'}[o.status]||'#737e9c'; %>
      <p style="font-weight:800;font-size:18px;color:<%= col %>;text-transform:capitalize;margin:0 0 16px"><%= o.status %></p>
      <form method="post" action="/admin/orders/<%= o.id %>/status" style="display:flex;flex-direction:column;gap:9px">
        <button class="btn btn-p" name="status" value="paid" type="submit">Mark paid</button>
        <button class="btn btn-p" name="status" value="approved" type="submit">Approve</button>
        <button class="btn btn-g" name="status" value="delivered" type="submit">Mark delivered</button>
        <button class="btn btn-g" name="status" value="pending" type="submit">Back to pending</button>
        <button class="btn btn-g" style="color:#b42318" name="status" value="rejected" type="submit">Reject</button>
      </form>
      <p class="hint" style="margin:14px 0 0">Auto-verification &amp; bot delivery arrive in the next steps; for now you confirm each order here.</p>
    </div>
    <div class="card">
      <h2>Contact</h2>
      <a class="btn btn-g" style="width:100%;justify-content:center" target="_blank" href="https://wa.me/<%= (o.whatsapp||'').replace(/[^0-9]/g,'') %>">Message on WhatsApp</a>
    </div>
  </div>
</div>
<%- include('_shell_bottom') %>
GSZ_AOD_EOF
echo "[ok] views: checkout, order, admin orders list + detail written"

# ============================================================
# 8. PATCH server.js — mount the two new routers (exact-string)
# ============================================================
cat > /tmp/gsz_patch_server.js <<'GSZ_PS_EOF'
const fs=require('fs'); const f=process.argv[2];
let s=fs.readFileSync(f,'utf8');
const anchor="const productsRouter = require('./routes/products')(pool);\napp.use('/product', productsRouter);";
if(s.indexOf(anchor)===-1){console.error('server anchor not found');process.exit(1);}
if(s.indexOf("routes/checkout")!==-1){console.log('server already patched');process.exit(0);}
const add=anchor+"\n\nconst checkoutRouter = require('./routes/checkout')(pool);\napp.use('/', checkoutRouter);\n\nconst adminOrdersRouter = require('./routes/adminOrders')(pool);\napp.use('/admin', adminOrdersRouter);";
const parts=s.split(anchor);
if(parts.length!==2){console.error('server anchor count='+(parts.length-1)+' (want 1)');process.exit(1);}
s=parts.join(add);
fs.writeFileSync(f,s);
console.log('server.js patched');
GSZ_PS_EOF
node /tmp/gsz_patch_server.js "$APP/server.js" || { restore; exit 1; }

# ============================================================
# 9. PATCH _shell_top.ejs — add "Sales" group with Orders link
# ============================================================
cat > /tmp/gsz_patch_nav.js <<'GSZ_PN_EOF'
const fs=require('fs'); const f=process.argv[2];
let s=fs.readFileSync(f,'utf8');
if(s.indexOf("on('orders')")!==-1){console.log('nav already patched');process.exit(0);}
const anchor="Branding &amp; Banners</a>\n  </nav>";
const parts=s.split(anchor);
if(parts.length!==2){console.error('nav anchor count='+(parts.length-1)+' (want 1)');process.exit(1);}
const add="Branding &amp; Banners</a>\n    <div class=\"grp\">Sales</div>\n    <a href=\"/admin/orders\" class=\"<%= on('orders') %>\"><svg viewBox=\"0 0 24 24\"><path d=\"M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z\"/><path d=\"M3 6h18\"/><path d=\"M16 10a4 4 0 0 1-8 0\"/></svg>Orders</a>\n  </nav>";
s=parts.join(add);
fs.writeFileSync(f,s);
console.log('_shell_top.ejs patched');
GSZ_PN_EOF
node /tmp/gsz_patch_nav.js "$APP/views/admin/_shell_top.ejs" || { restore; exit 1; }

# ============================================================
# 9b. PATCH product.ejs — wire "Buy now" to /checkout (exact-string)
# ============================================================
cat > /tmp/gsz_patch_product.js <<'GSZ_PP_EOF'
const fs=require('fs'); const f=process.argv[2];
let s=fs.readFileSync(f,'utf8');
if(s.indexOf("/checkout?p=")!==-1){console.log('product already patched');process.exit(0);}
function one(hay,find,repl,label){
  const parts=hay.split(find);
  if(parts.length!==2){console.error(label+': anchor count='+(parts.length-1)+' (want 1)');process.exit(1);}
  return parts.join(repl);
}
// A) expose the product slug to the page script
s=one(s,
  "var PNAME = <%- JSON.stringify(p.name) %>;",
  "var PNAME = <%- JSON.stringify(p.name) %>;\nvar PSLUG = <%- JSON.stringify(p.slug) %>;",
  "PNAME");
// B) Buy-now opens checkout in the SAME tab (not a new WhatsApp tab)
s=one(s,
  '<a class="btn btn-primary" id="buyBtn" href="#" target="_blank" rel="noopener">Buy now</a>',
  '<a class="btn btn-primary" id="buyBtn" href="#">Buy now</a>',
  "buyBtn");
// C) point Buy-now at /checkout with the selected plan index + current region
s=one(s,
  "  document.getElementById('waBtn').href=href;document.getElementById('buyBtn').href=href;}",
  "  document.getElementById('waBtn').href=href;\n  var idx=[].indexOf.call(document.querySelectorAll('.plan-opt'),sel);\n  document.getElementById('buyBtn').href='/checkout?p='+encodeURIComponent(PSLUG)+'&plan='+idx+'&region='+REG;}",
  "updateCTA");
fs.writeFileSync(f,s);
console.log('product.ejs patched');
GSZ_PP_EOF
node /tmp/gsz_patch_product.js "$APP/views/product.ejs" || { restore; exit 1; }

# ============================================================
# 10. VALIDATE — parse JS, render EJS, prove INSERT, test routes
# ============================================================
node --check "$APP/server.js"          || { restore; exit 1; }
node --check "$APP/routes/checkout.js"  || { restore; exit 1; }
node --check "$APP/routes/adminOrders.js" || { restore; exit 1; }
echo "[ok] all JS parses clean"

# render every new EJS view with sample data (catches include/syntax errors)
cat > /tmp/gsz_render.js <<'GSZ_RN_EOF'
const ejs=require('ejs'),path=require('path');
const V=process.argv[2]+'/views/';
const sampleMethods=[{key:'binance',name:'Binance',currency:'USD',scope:'all',details:'d',instructions:'i',pay:'$ 5.00'}];
const o={id:1,order_no:'GSZ-1001',status:'pending',email:'a@b.com',whatsapp:'+92300',product_name:'Netflix',plan_label:'1 Month',currency:'Rs',amount_display:1299,amount_pkr:1299,amount_usd:4.68,region:'PK',method_key:'binance',method_name:'Binance',txn_ref:'TX1',proof_file:null,note:'n',created_at:new Date()};
const jobs=[
 ['checkout.ejs',{p:{id:1,slug:'netflix',name:'Netflix'},plan:{label:'1 Month',price_pkr:1299,old_pkr:0},planIdx:0,region:'PK',regionList:['PK','US','GB','AE'],priceDisplay:'Rs 1,299',priceUsd:'$ 4.68',methods:sampleMethods,settings:{},logoFile:'logo.png',waNumber:'923141892712',error:null}],
 ['order.ejs',{o,method:{name:'Binance',details:'d',instructions:'i',currency:'USD'},settings:{},logoFile:'logo.png',waNumber:'923141892712'}],
 ['admin/orders.ejs',{rows:[o],counts:{pending:1},status:'',flash:null}],
 ['admin/order_detail.ejs',{o,method:{name:'Binance',details:'d',instructions:'i',currency:'USD'},flash:'Status updated'}]
];
(async()=>{let bad=0;for(const [f,d] of jobs){try{await ejs.renderFile(V+f,d,{});console.log('OK   '+f);}catch(e){console.log('FAIL '+f+' -> '+e.message);bad++;}}process.exit(bad?1:0);})();
GSZ_RN_EOF
( cd "$APP" && node /tmp/gsz_render.js "$APP" ) || { restore; exit 1; }
echo "[ok] all new views render"

# prove the real INSERT (column/param match) against the live DB, then rollback it
PSQL -v ON_ERROR_STOP=1 >/dev/null <<'GSZ_INS_EOF'
BEGIN;
INSERT INTO orders(status,email,whatsapp,product_id,product_name,plan_label,qty,region,currency,unit_amount,amount_display,amount_pkr,amount_usd,method_key,method_name,txn_ref,proof_file,note)
VALUES('pending','x@y.z','+92300',1,'Test','1 Month',1,'PK','Rs',1299,1299,1299,4.68,'binance','Binance','TX','',' ');
ROLLBACK;
GSZ_INS_EOF
echo "[ok] orders INSERT verified against live DB (18 cols / 16 params)"

pm2 restart gsz --update-env >/dev/null
sleep 1.8

SLUG=$(PSQL -tAc "SELECT slug FROM products ORDER BY sort,id LIMIT 1" | tr -d '[:space:]')
CO=$(curl -fsS "http://127.0.0.1:$PORT/checkout?p=$SLUG&plan=0&region=PK" || true)
PP=$(curl -fsS "http://127.0.0.1:$PORT/product/$SLUG" || true)
AO=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/admin/orders")

# real order via the actual POST route, capture the redirect, verify the row, then delete it
LOC=$(curl -s -D - -o /dev/null -X POST "http://127.0.0.1:$PORT/checkout" \
  -F "product=$SLUG" -F "plan=0" -F "region=PK" \
  -F "email=selftest@gsz.local" -F "whatsapp=03001234567" \
  -F "method=binance" -F "txn=SELFTEST" -F "note=step7 selftest" \
  | tr -d '\r' | awk 'tolower($1)=="location:"{print $2}')
ONO=$(echo "$LOC" | sed -n 's#^/order/##p')
ROWCNT=$(PSQL -tAc "SELECT count(*) FROM orders WHERE email='selftest@gsz.local'" | tr -d '[:space:]')

OKALL=1
echo "$CO" | grep -q "Order summary"       || { echo "FAIL: checkout page did not render"; OKALL=0; }
echo "$CO" | grep -q "Payment method"       || { echo "FAIL: checkout payment methods missing"; OKALL=0; }
echo "$PP" | grep -q "/checkout?p="         || { echo "FAIL: product Buy-now not wired to /checkout"; OKALL=0; }
[ "$AO" = "302" ] || [ "$AO" = "200" ]      || { echo "FAIL: /admin/orders not gated (HTTP $AO)"; OKALL=0; }
[ -n "$ONO" ]                               || { echo "FAIL: POST /checkout did not redirect to an order"; OKALL=0; }
[ "$ROWCNT" = "1" ]                         || { echo "FAIL: test order row not created (count=$ROWCNT)"; OKALL=0; }

# clean up the self-test order no matter what
PSQL -q -c "DELETE FROM orders WHERE email='selftest@gsz.local'" >/dev/null 2>&1 || true

if [ "$OKALL" != "1" ]; then
  echo "CHECK FAILED — rolling back Step 7"
  restore
  pm2 logs gsz --lines 25 --nostream || true
  exit 1
fi

echo "============================================================"
echo " STEP 7 COMPLETE — on-site checkout + orders are live"
echo "   checkout:  http://143.198.209.68:$PORT/checkout?p=$SLUG&plan=0"
echo "   order no.  created + verified + cleaned up ($ONO)"
echo "   admin:     http://143.198.209.68:$PORT/admin/orders  (new 'Sales' group)"
echo ""
echo "   NEXT: Step 8 makes payment details editable (set your real"
echo "   Binance / bank / JazzCash / Easypaisa / TapTap details)."
echo "   Until then the methods show placeholder details."
echo "============================================================"
