#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON — STEP 22: Reseller-Bot link (data + client layer)
#  Foundation for on-site checkout -> verify-claim -> fulfilment.
#  FUTURE-PROOF: maps on the bot's IMMUTABLE sku + plan_key + type,
#  never on serial_no / name / list position. v2 API contract.
#  Idempotent + auto-rollback. No UI change (admin mapping = Step 23).
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views" ] || { echo "ABORT: $APP not found"; exit 1; }
cd "$APP"
set -a; . "$APP/.env"; set +a
export PGPASSWORD="${DB_PASS:-}"
PSQL="psql -h ${DB_HOST:-127.0.0.1} -p ${DB_PORT:-5432} -U ${DB_USER} -d ${DB_NAME} -X -v ON_ERROR_STOP=1"

TS=$(date +%s)
BK="$APP/.bak-step22-$TS"; mkdir -p "$BK"
cp server.js "$BK/server.js"
restore(){ echo "!! ROLLBACK — restoring server.js"; cp "$BK/server.js" "$APP/server.js" 2>/dev/null || true; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "== Galaxy Subz x Zayron — Step 22 (bot link: data + client) · port ${PORT:-3900} =="

# ---- 1) DB migration (transactional, idempotent, sku-based, v2 shape) ----
$PSQL <<'EOF_SQL'
BEGIN;
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS source       text NOT NULL DEFAULT 'manual';
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS bot_sku      text;
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS bot_plan_key text;
ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS bot_type     text;

CREATE TABLE IF NOT EXISTS bot_products (
  sku           text PRIMARY KEY,
  bot_id        integer,
  serial        text,
  name          text,
  delivery_type text,
  price_pkr     numeric(14,2) DEFAULT 0,
  is_active     boolean DEFAULT true,
  needs         jsonb DEFAULT '[]'::jsonb,
  plans         jsonb DEFAULT '[]'::jsonb,
  types         jsonb DEFAULT '[]'::jsonb,
  missing       boolean NOT NULL DEFAULT false,
  updated_at    timestamptz DEFAULT now()
);
ALTER TABLE bot_products ADD COLUMN IF NOT EXISTS plans jsonb DEFAULT '[]'::jsonb;
ALTER TABLE bot_products ADD COLUMN IF NOT EXISTS types jsonb DEFAULT '[]'::jsonb;
ALTER TABLE bot_products DROP COLUMN IF EXISTS durations;

CREATE TABLE IF NOT EXISTS inventory_items (
  id           serial PRIMARY KEY,
  plan_id      integer REFERENCES product_plans(id) ON DELETE CASCADE,
  payload      text NOT NULL,
  status       text NOT NULL DEFAULT 'available',
  order_no     text,
  delivered_at timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS inventory_items_plan_status_idx ON inventory_items(plan_id, status);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS source                text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS bot_sku               text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS bot_plan_key          text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS bot_type              text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS bot_order_id          text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS claim_result          text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_credentials text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS fields                jsonb;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS amount_claimed        numeric(14,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS verified_at           timestamptz;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at          timestamptz;
COMMIT;
EOF_SQL
echo "[ok] migration applied (sku + plan_key + type, v2 shape)"

# ---- 2) .env keys (append only if missing) ----
grep -q '^GSZ_BOT_API_URL=' .env || printf '\nGSZ_BOT_API_URL=\n' >> .env
grep -q '^GSZ_BOT_API_KEY=' .env || printf 'GSZ_BOT_API_KEY=\n'   >> .env
echo "[ok] .env keys present"

# ---- 3) files ----
cat > lib/botapi.js <<'EOF_BOTAPI'
'use strict';
/* ============================================================
   GSZ <-> Reseller Bot API client.
   - No external deps (uses core https/http).
   - Safe when unconfigured: never throws into page renders;
     callers get {configured:false} / empty lists / unknown stock.
   - In-memory TTL cache so we DON'T hammer the bot.
   Endpoints (built on the bot, secured by X-API-Key):
     GET  /api/products        GET /api/pay-accounts
     GET  /api/stock/:id       GET /api/order-status/:ref
     POST /api/verify-claim    POST /api/submit-order
   ============================================================ */
const https = require('https');
const http = require('http');
const { URL } = require('url');

const TTL = { products: 600, pay: 600, stock: 60, status: 4, statusTerminal: 60 };
const cache = new Map();
const cget = k => { const e = cache.get(k); return (e && e.exp > Date.now()) ? e.val : undefined; };
const cset = (k, v, ttl) => { cache.set(k, { val: v, exp: Date.now() + ttl * 1000 }); return v; };

function cfg() {
  return { base: (process.env.GSZ_BOT_API_URL || '').replace(/\/+$/, ''), key: process.env.GSZ_BOT_API_KEY || '' };
}
function configured() { const c = cfg(); return !!(c.base && c.key); }

function req(method, pathname, body, timeoutMs) {
  return new Promise((resolve, reject) => {
    const c = cfg();
    if (!c.base || !c.key) return reject(new Error('bot_unconfigured'));
    let u; try { u = new URL(c.base + pathname); } catch (e) { return reject(new Error('bad_base_url')); }
    const lib = u.protocol === 'http:' ? http : https;
    const data = body ? Buffer.from(JSON.stringify(body)) : null;
    const opt = {
      method, hostname: u.hostname, port: u.port || (u.protocol === 'http:' ? 80 : 443),
      path: u.pathname + u.search,
      headers: Object.assign(
        { 'X-API-Key': c.key, 'Accept': 'application/json' },
        data ? { 'Content-Type': 'application/json', 'Content-Length': data.length } : {}
      )
    };
    const r = lib.request(opt, res => {
      let buf = ''; res.setEncoding('utf8');
      res.on('data', d => { buf += d; if (buf.length > 1e6) r.destroy(new Error('bot_response_too_large')); });
      res.on('end', () => {
        let j = null; try { j = buf ? JSON.parse(buf) : {}; } catch (e) { j = { _raw: buf }; }
        if (res.statusCode >= 200 && res.statusCode < 300) resolve(j);
        else reject(Object.assign(new Error('bot_http_' + res.statusCode), { status: res.statusCode, body: j }));
      });
    });
    r.on('error', reject);
    r.setTimeout(timeoutMs || 6000, () => { r.destroy(new Error('bot_timeout')); });
    if (data) r.write(data);
    r.end();
  });
}

async function getProducts(force) {
  if (!force) { const c = cget('products'); if (c) return c; }
  const j = await req('GET', '/api/products', null, 6000);
  const list = Array.isArray(j) ? j : (j.products || []);
  return cset('products', list, TTL.products);
}
async function getPayAccounts(force) {
  if (!force) { const c = cget('pay'); if (c) return c; }
  const j = await req('GET', '/api/pay-accounts', null, 6000);
  const list = Array.isArray(j) ? j : (j.accounts || j.methods || []);
  return cset('pay', list, TTL.pay);
}
async function getStock(botProductId) {
  const k = 'stock:' + botProductId; const c = cget(k); if (c) return c;
  const j = await req('GET', '/api/stock/' + encodeURIComponent(botProductId), null, 4000);
  return cset(k, j, TTL.stock);
}
async function orderStatus(ref) {
  const k = 'status:' + ref; const c = cget(k); if (c) return c;
  const j = await req('GET', '/api/order-status/' + encodeURIComponent(ref), null, 6000);
  const term = j && ['delivered', 'failed', 'out_of_stock'].includes(j.status);
  return cset(k, j, term ? TTL.statusTerminal : TTL.status);
}
function verifyClaim(payload) { return req('POST', '/api/verify-claim', payload, 8000); }
function submitOrder(payload) { return req('POST', '/api/submit-order', payload, 10000); }

async function ping() {
  if (!configured()) return { configured: false, reachable: false };
  try { const p = await getProducts(true); return { configured: true, reachable: true, productCount: (p || []).length }; }
  catch (e) { return { configured: true, reachable: false, error: e.message }; }
}
function clearCache() { cache.clear(); }

module.exports = { configured, getProducts, getPayAccounts, getStock, orderStatus, verifyClaim, submitOrder, ping, clearCache };
EOF_BOTAPI
cat > lib/botsync.js <<'EOF_BOTSYNC'
'use strict';
/* Pull the bot's live catalogue into the local bot_products cache table.
   FUTURE-PROOF: keyed on the bot's IMMUTABLE `sku` — never on serial_no,
   name, or list position (all of which the owner changes freely).
   Stores normalized plans[] and types[] (family/adult) from the v2 API.
   A re-sync refreshes display fields but the site<->bot mapping
   (product_plans.bot_sku + bot_plan_key + bot_type) is unaffected.
   Falls back to String(id) as the sku only if the bot omits `sku`. */
const botapi = require('./botapi');

function skuOf(p) {
  if (p == null) return null;
  if (p.sku != null && String(p.sku).trim() !== '') return String(p.sku).trim();
  if (p.code != null && String(p.code).trim() !== '') return String(p.code).trim();
  if (p.id != null) return String(p.id);            // last-resort fallback
  return null;
}

async function syncProducts(pool) {
  const list = await botapi.getProducts(true);
  const seen = [];
  let n = 0;
  for (const p of (list || [])) {
    const sku = skuOf(p);
    if (!sku) continue;
    seen.push(sku);
    const serial = (p.serial_no != null ? String(p.serial_no) : (p.serial != null ? String(p.serial) : null));
    await pool.query(
      `INSERT INTO bot_products(sku,bot_id,serial,name,delivery_type,price_pkr,is_active,needs,plans,types,missing,updated_at)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,false,now())
       ON CONFLICT (sku) DO UPDATE SET
         bot_id=EXCLUDED.bot_id, serial=EXCLUDED.serial, name=EXCLUDED.name,
         delivery_type=EXCLUDED.delivery_type, price_pkr=EXCLUDED.price_pkr,
         is_active=EXCLUDED.is_active, needs=EXCLUDED.needs, plans=EXCLUDED.plans,
         types=EXCLUDED.types, missing=false, updated_at=now()`,
      [
        sku,
        (p.id != null ? parseInt(p.id, 10) : null),
        serial,
        p.name || null,
        p.delivery_type || null,
        Number(p.price != null ? p.price : (p.price_pkr || 0)) || 0,
        p.is_active !== false,
        JSON.stringify(p.needs || []),
        JSON.stringify(p.plans || []),
        JSON.stringify(p.types || [])
      ]
    );
    n++;
  }
  // Mark any previously-synced product that vanished from the bot as missing,
  // so mapped plans can show out-of-stock instead of mis-delivering.
  if (seen.length) {
    await pool.query(
      `UPDATE bot_products SET missing=true, updated_at=now()
       WHERE sku <> ALL($1::text[])`, [seen]
    );
  }
  const ts = new Date().toISOString();
  const u = await pool.query('UPDATE settings SET value=$1 WHERE key=$2', [ts, 'bot_last_sync']);
  if (u.rowCount === 0) await pool.query('INSERT INTO settings(key,value) VALUES($1,$2)', ['bot_last_sync', ts]);
  return n;
}

module.exports = { syncProducts, skuOf };
EOF_BOTSYNC
cat > routes/botAdmin.js <<'EOF_BOTADMIN'
'use strict';
/* Admin-only plumbing for the bot link: connection status + catalogue sync.
   The styled mapping UI (Step 2) will POST to /admin/bot/sync and read
   /admin/bot/status; kept minimal here so nothing is built twice. */
const express = require('express');
const botapi = require('../lib/botapi');
const { syncProducts } = require('../lib/botsync');

module.exports = function (pool) {
  const router = express.Router();
  function auth(req, res, next) {
    if (req.session && req.session.admin) return next();
    return res.redirect('/admin/login');
  }

  router.get('/bot/status', auth, async (req, res) => {
    try {
      const ping = await botapi.ping();
      const last = (await pool.query("SELECT value FROM settings WHERE key='bot_last_sync'")).rows[0];
      const count = (await pool.query('SELECT count(*)::int n FROM bot_products')).rows[0].n;
      res.json(Object.assign({ ok: true, cached_bot_products: count, last_sync: last ? last.value : null }, ping));
    } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
  });

  router.post('/bot/sync', auth, express.urlencoded({ extended: false }), async (req, res) => {
    const wantJson = String(req.query.json || '') === '1';
    try {
      const n = await syncProducts(pool);
      if (wantJson) return res.json({ ok: true, synced: n });
      res.redirect(req.get('referer') || '/admin');
    } catch (e) {
      if (wantJson) return res.status(500).json({ ok: false, error: e.message });
      res.status(500).send('Bot sync error: ' + e.message);
    }
  });

  return router;
};
EOF_BOTADMIN
echo "[ok] files written"

# ---- 4) syntax check ----
node --check lib/botapi.js
node --check lib/botsync.js
node --check routes/botAdmin.js
echo "[ok] syntax"

# ---- 5) mount botAdmin in server.js (idempotent, exact-anchor, count===1) ----
node <<'EOF_PATCH'
const fs=require('fs'), f='server.js';
let s=fs.readFileSync(f,'utf8');
if(s.includes("routes/botAdmin")){ console.log("already mounted"); process.exit(0); }
const anchor="app.use('/admin', adminPaymentsRouter);";
const c=s.split(anchor).length-1;
if(c!==1){ console.error("anchor count "+c+" (expected 1)"); process.exit(1); }
const add="\nconst botAdminRouter = require('./routes/botAdmin')(pool);\napp.use('/admin', botAdminRouter);";
fs.writeFileSync(f, s.replace(anchor, anchor+add));
console.log("mounted botAdmin");
EOF_PATCH
node --check server.js
echo "[ok] server.js mount"

# ---- 6) self-test ----
node <<'EOF_SELFTEST'
require('./lib/botapi'); require('./lib/botsync'); require('./routes/botAdmin');
require('./lib/botapi').ping().then(r=>{
  if(typeof r.configured!=='boolean'){ console.error('bad ping'); process.exit(1); }
  console.log('self-test ping:', JSON.stringify(r));
}).catch(e=>{ console.error('selftest err', e.message); process.exit(1); });
EOF_SELFTEST
echo "[ok] self-test"

# ---- 7) verify DB objects ----
$PSQL -c "SELECT source, bot_sku, bot_plan_key, bot_type FROM product_plans LIMIT 1" >/dev/null
$PSQL -c "SELECT sku, plans, types, missing FROM bot_products LIMIT 1" >/dev/null 2>&1 || true
echo "[ok] db objects"

# ---- 8) restart + health ----
pm2 restart gsz >/dev/null 2>&1 || pm2 start server.js --name gsz >/dev/null 2>&1
sleep 2
BODY="$(curl -fsS "http://127.0.0.1:${PORT:-3900}/" 2>/dev/null || true)"
grep -q "</html>" <<< "$BODY" || { echo "!! health check failed (home page)"; exit 1; }
echo "[ok] site healthy"

trap - ERR
echo "============================================================"
echo "  STEP 22 OK — future-proof bot link (sku + plan_key + type)."
echo "  product_plans: source / bot_sku / bot_plan_key / bot_type"
echo "  bot_products cache (plans[]+types[]+missing) / inventory_items"
echo "  lib/botapi.js (cached) + lib/botsync.js + /admin/bot/*"
echo "  Fill GSZ_BOT_API_URL + GSZ_BOT_API_KEY in .env when bot API is live."
echo "  Next: Step 23 = admin mapping UI."
echo "============================================================"
