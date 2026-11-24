#!/usr/bin/env bash
# stepZayronProv3 — PROVISIONING via the shared gsz-api bridge (replaces the dead direct-DB path).
#  - lib/orderDispatch.js: fully replaced. resolve(sku,planLabel,type) off /api/products,
#    submit() -> gszApi.submitOrder, poll(ref) -> gszApi.orderStatus (parses the line from fields).
#    No DB creds in the file anymore.
#  - orderWorker.dispatchOrder: uses server.bot_sku (owner-mapped) + submit; renewals/unmapped -> review.
#  - orderWorker.runCollect: polls by order.ref.
#  - checkout.js: adult-availability check uses bot_sku (no more dead-DB 8s hang).
# Delivery WhatsApp, verify, hardening all unchanged. Safe: backups, anchors+auto-revert, node --check.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zp3; rm -rf "$W"; mkdir -p "$W/p"
cp lib/orderDispatch.js "$W/orderDispatch.js.bak"
cp lib/orderWorker.js   "$W/orderWorker.js.bak"
cp routes/checkout.js   "$W/checkout.js.bak"
revert(){ cp "$W/orderDispatch.js.bak" lib/orderDispatch.js; cp "$W/orderWorker.js.bak" lib/orderWorker.js; cp "$W/checkout.js.bak" routes/checkout.js; }

# ---------- 1) new lib/orderDispatch.js (bridge-based, no DB creds) ----------
cat > lib/orderDispatch.js <<'DISP'
'use strict';
/* orderDispatch.js — turns a VERIFIED order into a real IPTV line through the shared gsz-api
   bridge (the ONE engine, same as galaxyzayron). No direct DB, no credentials in this file.
   resolve(): map the server's owner-chosen bot sku + plan label + content type -> {sku,plan_key,type}
   submit():  POST /api/submit-order   poll(): GET /api/order-status/:ref (parses the line out). */
const gszApi = require('./gszApi');

// Website wording vs bot wording — reduce to a month count so "1 Year" == "12 Months", etc.
const DURATION_ALIASES = [
  { months: 1,  re: /^(1month|1mo|1m|onemonth|monthly)$/ },
  { months: 3,  re: /^(3months|3month|3mo|3m|threemonths|quarterly)$/ },
  { months: 6,  re: /^(6months|6month|6mo|6m|sixmonths|halfyear|halfyearly)$/ },
  { months: 12, re: /^(12months|12month|12mo|12m|1year|1yr|1y|oneyear|yearly|annual|annually)$/ }
];
function normLabel(v) { return String(v || '').toLowerCase().replace(/[^a-z0-9]/g, ''); }
function monthsOf(label) {
  const n = normLabel(label);
  for (const a of DURATION_ALIASES) if (a.re.test(n)) return a.months;
  const m = n.match(/^(\d+)(month|months|mo|m)$/); if (m) return parseInt(m[1], 10);
  const y = n.match(/^(\d+)(year|years|yr|y)$/);   if (y) return parseInt(y[1], 10) * 12;
  return null;
}

// Resolve the owner-mapped bot product + plan. `sku` is servers.bot_sku (chosen in Admin).
async function resolvePackage(sku, planLabel, contentType) {
  try {
    if (!sku) return { ok: false, error: 'server not mapped to a bot product' };
    const prod = await gszApi.getProducts();
    const list = (prod && prod.products) || [];
    const p = list.find(function (x) { return String(x.sku) === String(sku); });
    if (!p) return { ok: false, error: 'bot product ' + sku + ' not found' };
    if (p.delivery_type !== 'iptv') return { ok: false, error: 'mapped product is not iptv' };
    const plans = Array.isArray(p.plans) ? p.plans : [];
    const want = normLabel(planLabel);
    let d = plans.find(function (x) { return normLabel(x.label) === want; });
    if (!d) d = plans.find(function (x) { const n = normLabel(x.label); return n && (n.indexOf(want) >= 0 || want.indexOf(n) >= 0); });
    if (!d) { const wm = monthsOf(planLabel); if (wm) d = plans.find(function (x) { return monthsOf(x.label) === wm; }); }
    if (!d) return { ok: false, error: 'no matching plan for "' + planLabel + '" on ' + p.name };
    if (String(d.plan_key) === 'trial') return { ok: false, error: 'trial plan cannot be purchased' };
    const wantAdult = /adult|18|xxx/i.test(String(contentType || ''));
    const types = Array.isArray(p.types) ? p.types.map(function (t) { return String(t.key); }) : [];
    let type;
    if (wantAdult) {
      if (types.indexOf('adult') < 0) return { ok: false, error: 'Adult is not available on ' + p.name };
      type = 'adult';
    } else {
      type = (types.indexOf('family') >= 0) ? 'family' : (types[0] || 'family');
    }
    return { ok: true, sku: String(p.sku), plan_key: String(d.plan_key), type: type, label: d.label, price: d.price, adult: (type === 'adult'), productName: p.name };
  } catch (e) { return { ok: false, error: e.message }; }
}

// Submit a verified order to the bridge for provisioning. Returns the bridge's JSON.
async function submit(opts) {
  const o = opts || {};
  return gszApi.submitOrder({
    ref: o.ref, sku: o.sku, plan_key: o.plan_key, type: o.type,
    userPhone: o.phone || undefined, userName: o.name || undefined,
    planLabel: o.planLabel || undefined, productName: o.productName || undefined,
    source: 'zayron-web'
  });
}

// Pull a delivered line out of order-status fields (username/password/host/expiry).
function extractLine(fields) {
  const out = { username: null, password: null, host: null, m3u: null, expiry: null };
  const details = (fields && Array.isArray(fields.details)) ? fields.details : [];
  details.forEach(function (d) {
    const l = String(d.label || '').toLowerCase(); const v = String(d.value || '');
    if (!v) return;
    if (/user|login|account/.test(l) && !out.username) out.username = v;
    else if (/pass|pwd/.test(l) && !out.password) out.password = v;
    else if (/(m3u)/.test(l) && !out.m3u) out.m3u = v;
    else if (/(url|dns|server|host|portal|link)/.test(l) && !out.host) out.host = v;
  });
  if (fields && fields.expiry) out.expiry = fields.expiry;
  return out;
}

// Poll the bridge by the website order ref. Maps to the worker's expected shape.
async function poll(ref) {
  try {
    const st = await gszApi.orderStatus(ref);
    if (!st || st.ok === false) return { status: 'pending' };
    if (st.status === 'delivered') return { status: 'done', result: extractLine(st.fields), card: st.delivered_credentials || '' };
    if (st.status === 'failed') return { status: 'failed', error: st.message || 'provisioning failed' };
    if (st.status === 'out_of_stock') return { status: 'failed', error: 'out of stock' };
    return { status: 'pending' };
  } catch (e) { return { status: 'error', error: e.message }; }
}

module.exports = { resolvePackage, submit, poll };
DISP
node --check lib/orderDispatch.js || { echo "orderDispatch syntax error - reverting"; revert; exit 1; }

# ---------- 2) orderWorker.dispatchOrder — use bot_sku + bridge submit ----------
cat > "$W/p/o1" <<'OLD'
    const sv = (await pool.query('SELECT id,name,slug,reseller_pid FROM servers WHERE id=$1', [order.server_id])).rows[0];
    if (!sv) return { ok: false, error: 'server not found' };
    if (!sv.reseller_pid) {
      await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2",
        ['Manual delivery — no panel mapped for ' + sv.name, order.id]);
      return { ok: false, error: 'manual panel' };
    }
    const res = await dispatch.resolvePackage(sv.reseller_pid, order.plan_label, order.content_type);
    if (!res.ok) {
      await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2",
        ['Could not resolve package: ' + res.error, order.id]);
      return { ok: false, error: res.error };
    }
    const payload = {
      panelId: sv.reseller_pid, packageId: res.packageId, adult: res.adult,
      planLabel: order.plan_label, productName: sv.name, phone: order.payer_name || 'WEB',
      renewUsername: order.kind === 'renewal' ? (order.renew_username || null) : null
    };
    if (dryRun) { log.log('[dryrun] would dispatch', order.ref, JSON.stringify(payload)); return { ok: true, dryRun: true, payload: payload }; }
    const jobId = await dispatch.enqueue(payload);
    await pool.query("UPDATE orders SET bot_job_id=$1, status='provisioning', updated_at=now() WHERE id=$2", [jobId, order.id]);
    log.log('[dispatch]', order.ref, '-> job', jobId, payload.renewUsername ? '(renewal)' : '(new line)');
    return { ok: true, jobId: jobId };
OLD
cat > "$W/p/n1" <<'NEW'
    const sv = (await pool.query('SELECT id,name,slug,reseller_pid,bot_sku FROM servers WHERE id=$1', [order.server_id])).rows[0];
    if (!sv) return { ok: false, error: 'server not found' };
    // renewals aren't wired through the bridge yet — hand to manual review rather than mis-provision
    if (order.kind === 'renewal') {
      if (dryRun) return { ok: false, error: 'renewal (manual)' };
      await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2",
        ['Renewal — extend the line by hand, then set the details here', order.id]);
      return { ok: false, error: 'renewal manual' };
    }
    if (!sv.bot_sku) {
      if (dryRun) return { ok: false, error: 'not mapped' };
      await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2",
        ['Manual delivery — "' + sv.name + '" is not mapped to a bot product (Admin -> edit server -> Bot product)', order.id]);
      return { ok: false, error: 'not mapped' };
    }
    const res = await dispatch.resolvePackage(sv.bot_sku, order.plan_label, order.content_type);
    if (!res.ok) {
      await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2",
        ['Could not resolve plan: ' + res.error, order.id]);
      return { ok: false, error: res.error };
    }
    let _cust = {}; try { _cust = (await pool.query('SELECT phone, name FROM customers WHERE id=$1', [order.customer_id])).rows[0] || {}; } catch (e) {}
    const payload = {
      ref: order.ref, sku: res.sku, plan_key: res.plan_key, type: res.type,
      planLabel: order.plan_label, productName: sv.name,
      phone: _cust.phone || null, name: _cust.name || null
    };
    if (dryRun) { log.log('[dryrun] would submit', order.ref, JSON.stringify(payload)); return { ok: true, dryRun: true, payload: payload }; }
    const sr = await dispatch.submit(payload);
    if (!sr || sr.ok === false) {
      await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2",
        ['Bridge submit failed: ' + ((sr && (sr.error || sr.reason)) || 'unknown'), order.id]);
      return { ok: false, error: (sr && (sr.error || sr.reason)) || 'submit failed' };
    }
    await pool.query("UPDATE orders SET bot_job_id=$1, status='provisioning', updated_at=now() WHERE id=$2", [order.id, order.id]);
    log.log('[dispatch]', order.ref, '-> bridge (' + res.sku + '/' + res.plan_key + '/' + res.type + ')');
    return { ok: true, jobId: order.ref };
NEW

# ---------- 3) runCollect — poll by ref ----------
cat > "$W/p/o2" <<'OLD'
      const p = await dispatch.poll(o.bot_job_id);
OLD
cat > "$W/p/n2" <<'NEW'
      const p = await dispatch.poll(o.ref);
NEW

# ---------- 4) checkout adult-availability — use bot_sku, no dead DB ----------
cat > "$W/p/o3" <<'OLD'
      let ctAvail = false;
      try {
        if (sv.reseller_pid) {
          const dispatch = require('../lib/orderDispatch');
          const t = await dispatch.resolvePackage(sv.reseller_pid, o.plan_label, 'Adult');
          ctAvail = !!(t && t.ok);
        }
      } catch (e) { ctAvail = false; }
OLD
cat > "$W/p/n3" <<'NEW'
      let ctAvail = false;
      try {
        let _bsku = sv.bot_sku;
        if (_bsku == null) { try { const _sr = await pool.query('SELECT bot_sku FROM servers WHERE id=$1', [o.server_id]); _bsku = _sr.rows[0] && _sr.rows[0].bot_sku; } catch (e) {} }
        if (_bsku) {
          const dispatch = require('../lib/orderDispatch');
          const t = await dispatch.resolvePackage(_bsku, o.plan_label, 'Adult');
          ctAvail = !!(t && t.ok);
        }
      } catch (e) { ctAvail = false; }
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zp3/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+'] in '+file); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('lib/orderWorker.js','o1','n1');
rep('lib/orderWorker.js','o2','n2');
rep('routes/checkout.js','o3','n3');
console.log('PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
for f in lib/orderWorker.js routes/checkout.js; do node --check "$f" || { echo "syntax error in $f - reverting"; revert; exit 1; }; done

pm2 restart zayron zayron-orders >/dev/null 2>&1 || pm2 restart zayron zayron-orders
echo "DONE: provisioning now runs through the gsz-api bridge using each server's mapped bot product."
