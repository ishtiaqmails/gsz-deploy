#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON — STEP 24: delivery_type-aware checkout + stock gating
#  - Checkout collects the right extra fields per the mapped bot delivery_type
#    (MAC for player activations; link+qty for SMM). Email/WhatsApp always.
#  - Stock gating: bot 'stock' items (live, cached) and own-inventory plans
#    show "out of stock" and block ordering; everything else always available.
#  - Persists source/bot_sku/bot_plan_key/bot_type + customer fields on orders.
#  Price stays the site's own retail price_pkr. Manual checkout still works.
#  Files: routes/checkout.js, views/checkout.ejs. Idempotent + auto-rollback.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -f "$APP/routes/checkout.js" ] || { echo "ABORT: checkout.js not found"; exit 1; }
cd "$APP"
set -a; . "$APP/.env"; set +a
export PGPASSWORD="${DB_PASS:-}"
PSQL="psql -h ${DB_HOST:-127.0.0.1} -p ${DB_PORT:-5432} -U ${DB_USER} -d ${DB_NAME} -X -tAc"

TS=$(date +%s)
BK="$APP/.bak-step24-$TS"; mkdir -p "$BK"
cp routes/checkout.js "$BK/checkout.js"
cp views/checkout.ejs "$BK/checkout.ejs"
restore(){ echo "!! ROLLBACK"; cp "$BK/checkout.js" "$APP/routes/checkout.js" 2>/dev/null||true; cp "$BK/checkout.ejs" "$APP/views/checkout.ejs" 2>/dev/null||true; pm2 restart gsz >/dev/null 2>&1||true; }
trap 'restore' ERR

echo "== Galaxy Subz x Zayron — Step 24 (checkout: delivery_type + stock) · port ${PORT:-3900} =="

cat > routes/checkout.js <<'EOF_CHECKOUT_JS'
const path = require('path');
const fs = require('fs');
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
    if (m.currency === 'USD') return fmt('$', usd);
    return fmt(dispCur, disp);
  }

  // which EXTRA fields the customer must give, by the bot delivery_type
  function customerFields(deliveryType) {
    if (['hotplayer', 'ibosol', 'zayron'].includes(deliveryType)) return ['mac'];
    if (deliveryType === 'smm') return ['link', 'qty'];
    return [];
  }

  // live availability for a plan (bot stock / own inventory / always)
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
      // bot hiccup → don't block the sale here; submit-order re-checks at fulfilment
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
      const allm = (await pool.query('SELECT key,name,currency,scope,details,instructions FROM payment_methods WHERE active ORDER BY sort,id')).rows;
      const methods = allm.filter(m => visible(region, m)).map(m => Object.assign({}, m, { pay: quote(m, pkr, usd, R.cur, disp) }));
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
      const m = (await pool.query('SELECT key, name, currency, scope FROM payment_methods WHERE key=$1 AND active', [method_key])).rows[0];
      if (!m) return fail('Please choose a payment method.');

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

      const pkr = Number(plan.price_pkr || 0);
      const R = REGIONS[region];
      const disp = +(pkr * R.rate).toFixed(2);
      const usd = +(pkr * REGIONS.US.rate).toFixed(2);
      const proof = req.file ? req.file.filename : null;

      const ins = await pool.query(
        `INSERT INTO orders(status,email,whatsapp,product_id,product_name,plan_label,qty,region,currency,unit_amount,amount_display,amount_pkr,amount_usd,method_key,method_name,txn_ref,proof_file,note,source,bot_sku,bot_plan_key,bot_type,fields)
         VALUES('pending',$1,$2,$3,$4,$5,1,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21) RETURNING id`,
        [email, whatsapp, prow.id, prow.name, plan.label, region, R.cur, disp, disp, pkr, usd, m.key, m.name, txn, proof, note,
         plan.source || 'manual', plan.bot_sku || null, plan.bot_plan_key || null, plan.bot_type || null, JSON.stringify(fields)]
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
EOF_CHECKOUT_JS
cat > views/checkout.ejs <<'EOF_CHECKOUT_EJS'
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
  .oos{background:#fff6e5;color:#8a5a00;border:1px solid #ffe0a0;border-radius:11px;padding:13px 15px;font-size:14px;font-weight:600;margin-bottom:18px;line-height:1.5}
  .hint{font-size:12.5px;color:var(--muted);margin:-8px 0 14px}
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
  .instock{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;font-weight:700;color:#0b7a42}
  .instock .d{width:8px;height:8px;border-radius:50%;background:#16b765}
  .regsel{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--muted);margin-bottom:14px}
  .regsel select{width:auto;margin:0;padding:7px 10px;border-radius:8px}
  .btn{display:block;width:100%;text-align:center;background:var(--grad);color:#fff;font-weight:700;font-size:15.5px;border:0;border-radius:12px;padding:14px;cursor:pointer;box-shadow:0 14px 30px -14px rgba(42,123,255,.9)}
  .btn:hover{filter:brightness(1.04)}
  .btn[disabled]{opacity:.5;pointer-events:none;box-shadow:none}
  .btn-wa{display:block;width:100%;text-align:center;background:linear-gradient(135deg,#25d366,#0fb858);color:#fff;font-weight:700;font-size:15px;border-radius:12px;padding:13px;margin-top:10px}
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
    <% if (!avail.available) { %>
      <div class="oos">This plan is currently <b>out of stock</b>. Message us on WhatsApp and we'll restock fast, or pick another plan.</div>
    <% } %>

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

    <% if (needFields.includes('mac')) { %>
    <div class="card">
      <h2>Device details</h2>
      <label class="fld">MAC address of your player / device</label>
      <input type="text" name="mac" placeholder="AA:BB:CC:DD:EE:FF" required>
      <p class="hint">Find this in your player app under Settings → it's needed to activate your subscription.</p>
    </div>
    <% } %>

    <% if (needFields.includes('link') || needFields.includes('qty')) { %>
    <div class="card">
      <h2>Order details</h2>
      <% if (needFields.includes('link')) { %>
        <label class="fld">Target link (profile / post URL)</label>
        <input type="text" name="link" placeholder="https://..." required>
      <% } %>
      <% if (needFields.includes('qty')) { %>
        <label class="fld">Quantity</label>
        <input type="text" name="qty" placeholder="e.g. 1000" required>
      <% } %>
    </div>
    <% } %>

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

    <% if (avail.available) { %>
      <button class="btn" type="submit">Place order</button>
      <p class="fine">After you place the order, we verify your payment and deliver to your email & WhatsApp. You'll get an order number to track status.</p>
    <% } else { %>
      <button class="btn" type="submit" disabled>Out of stock</button>
      <% if (waNumber) { %>
        <a class="btn-wa" target="_blank" rel="noopener" href="https://wa.me/<%= waNumber.replace(/[^0-9]/g,'') %>?text=<%= encodeURIComponent('Hi! Is '+p.name+' ('+plan.label+') back in stock?') %>">Ask on WhatsApp</a>
      <% } %>
    <% } %>
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
      <% if (avail.available) { %>
        <div class="row"><span>Availability</span><span class="instock"><span class="d"></span><%= (avail.count!=null) ? (avail.count+' in stock') : 'In stock' %></span></div>
      <% } %>
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
EOF_CHECKOUT_EJS
echo "[ok] files written"

node --check routes/checkout.js
node <<'EOF_COMPILE'
const ejs=require('ejs'), fs=require('fs');
ejs.compile(fs.readFileSync('views/checkout.ejs','utf8'), {filename: process.cwd()+'/views/checkout.ejs'});
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
  grep -q "Order summary" <<< "$CO" || { echo "!! checkout render failed for /checkout?p=$SLUG"; exit 1; }
  echo "   checkout renders OK for product: $SLUG"
else
  echo "   (no product slug found to test checkout render)"
fi
echo "[ok] site healthy"

trap - ERR
echo "============================================================"
echo "  STEP 24 OK — checkout is delivery_type-aware + stock-gated."
echo "  - Player products ask for MAC; SMM asks for link+qty."
echo "  - Bot 'stock' items & empty inventory show out-of-stock + block."
echo "  - Orders now carry source + bot sku/plan/type + customer fields."
echo "  Next: Step 25 = payment verify-claim on order placement."
echo "============================================================"
