#!/usr/bin/env bash
# stepZayronOwnerNotify — owner order notifications for zayron.tv (same as galaxyzayron), routed through the reseller
# bot /api/notify (the live owner channel). Adds gszApi.notify, lib/notifyOwner.js, an owner_alerts dedup column, and
# hooks: 'new' on payment submit (checkout), 'delivered' + 'review' in the worker. Ends with a TEST alert to confirm.
# Safe: backup + single-match + revert + node --check + health loop.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp lib/gszApi.js "$B/"; cp routes/checkout.js "$B/"; cp lib/orderWorker.js "$B/"
revert(){ cp "$B/gszApi.js" lib/gszApi.js; cp "$B/checkout.js" routes/checkout.js; cp "$B/orderWorker.js" lib/orderWorker.js; rm -f lib/notifyOwner.js; pm2 restart zayron >/dev/null 2>&1 || true; pm2 restart zayron-orders >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# ---------- owner-alert builder ----------
cat > lib/notifyOwner.js <<'NJS'
'use strict';
// Zayron owner order alerts — routed through the SAME reseller-bot /api/notify that reaches the owner for
// galaxyzayron. Fail-safe: never throws into the request/worker path.
const gszApi = require('./gszApi');
async function notifyOwner(pool, orderId, event) {
  try {
    if (['new', 'delivered', 'review', 'rejected'].indexOf(event) < 0) return;
    if (!gszApi.configured || !gszApi.configured() || !gszApi.notify) return;
    const o = (await pool.query('SELECT * FROM orders WHERE id=$1', [orderId])).rows[0];
    if (!o) return;
    try {
      const claim = await pool.query(
        "UPDATE orders SET owner_alerts = COALESCE(owner_alerts,'') || $2 || ',' WHERE id=$1 AND COALESCE(owner_alerts,'') NOT LIKE '%' || $2 || ',%' RETURNING id",
        [o.id, event]);
      if (!claim.rows.length) return;
    } catch (e) {}
    let product = '';
    try { if (o.server_id) { const sv = (await pool.query('SELECT name FROM servers WHERE id=$1', [o.server_id])).rows[0]; product = (sv && sv.name) || ''; } } catch (e) {}
    let cust = {};
    try { cust = (await pool.query('SELECT name, phone, email FROM customers WHERE id=$1', [o.customer_id])).rows[0] || {}; } catch (e) {}
    let method = '';
    try { if (o.pay_method_id) { const pm = (await pool.query('SELECT name FROM payment_methods WHERE id=$1', [o.pay_method_id])).rows[0]; method = (pm && pm.name) || ''; } } catch (e) {}
    const TITLES = { new: '🔔 New website order', delivered: '✅ Order delivered', review: '🕵️ Payment needs review', rejected: '⛔ Payment rejected' };
    const title = TITLES[event] || ('🔔 Order ' + event);
    const amt = 'Rs ' + Number(o.pay_amount || o.price_amount || 0).toLocaleString('en-US');
    const L = [title + '  ·  Zayron', '', '🧾 Order: ' + (o.ref || ''), '📦 Product: ' + (product || '')];
    if (o.plan_label) L.push('🏷️ Plan: ' + o.plan_label);
    if (o.content_type) L.push('🎛️ Version: ' + o.content_type);
    L.push('👤 Customer: ' + [(cust && cust.name) || '', (cust && cust.phone) || ''].filter(Boolean).join(' — '));
    if (cust && cust.email) L.push('✉️ Email: ' + cust.email);
    L.push('💳 Payment: ' + (method || '—') + (o.payer_name ? (' (by ' + o.payer_name + (o.payer_last4 ? ' ***' + o.payer_last4 : '') + ')') : ''));
    L.push('💰 Amount: ' + amt);
    L.push('📊 Status: ' + (o.status || ''));
    const message = L.join('\n');
    await gszApi.notify({ event, title, message, text: message, ref: o.ref, order_no: o.ref, status: o.status, product, plan: o.plan_label, type: o.content_type || null, amount_display: amt, method, email: (cust && cust.email) || '', whatsapp: (cust && cust.phone) || '', source: 'zayron-web', site: 'zayron.tv', at: new Date().toISOString() });
  } catch (e) {}
}
module.exports = { notifyOwner };
NJS
node --check lib/notifyOwner.js || { echo "notifyOwner syntax error - aborting"; rm -f lib/notifyOwner.js; rm -rf "$T"; exit 1; }

# ---------- gszApi: add notify + export ----------
cat > "$T/g1_o" <<'O'
function verifyClaim(payload) { return req('POST', '/api/verify-claim', payload, 30000); }
O
cat > "$T/g1_n" <<'O'
function verifyClaim(payload) { return req('POST', '/api/verify-claim', payload, 30000); }
function notify(payload) { return req('POST', '/api/notify', payload, 6000); }
O
cat > "$T/g2_o" <<'O'
module.exports = { configured, getPayAccounts, getProducts, verifyClaim, orderStatus, submitOrder, generateTrial, trialStatus, methodKey };
O
cat > "$T/g2_n" <<'O'
module.exports = { configured, getPayAccounts, getProducts, verifyClaim, notify, orderStatus, submitOrder, generateTrial, trialStatus, methodKey };
O

# ---------- checkout: 'new' on payment submit ----------
cat > "$T/c_o" <<'O'
      } catch (e) {}
      res.redirect('/checkout/' + o.ref + '/status');
O
cat > "$T/c_n" <<'O'
      } catch (e) {}
      try { await require('../lib/notifyOwner').notifyOwner(pool, o.id, 'new'); } catch (e) {}
      res.redirect('/checkout/' + o.ref + '/status');
O

# ---------- worker: 'delivered' + 'review' ----------
cat > "$T/w1_o" <<'O'
        try { await notifyDelivered(o, r, url, exp, p.fields); } catch (e) { try { log.log('[deliver-notify-fail]', o.ref, e.message); } catch (_) {} }
        done++;
O
cat > "$T/w1_n" <<'O'
        try { await notifyDelivered(o, r, url, exp, p.fields); } catch (e) { try { log.log('[deliver-notify-fail]', o.ref, e.message); } catch (_) {} }
        try { await require('./notifyOwner').notifyOwner(pool, o.id, 'delivered'); } catch (e) {}
        done++;
O
cat > "$T/w2_o" <<'O'
        await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2",
          ['Bot could not create the line: ' + (p.error || 'unknown'), o.id]);
        failed++;
O
cat > "$T/w2_n" <<'O'
        await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2",
          ['Bot could not create the line: ' + (p.error || 'unknown'), o.id]);
        try { await require('./notifyOwner').notifyOwner(pool, o.id, 'review'); } catch (e) {}
        failed++;
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('/opt/zayron/lib/gszApi.js', [['g1_o','g1_n'],['g2_o','g2_n']]);
patch('/opt/zayron/routes/checkout.js', [['c_o','c_n']]);
patch('/opt/zayron/lib/orderWorker.js', [['w1_o','w1_n'],['w2_o','w2_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

# ---------- dedup column ----------
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();p.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS owner_alerts text').then(()=>{console.log('owner_alerts column OK');return p.end();}).catch(e=>{console.log('ALTER ERR',e.message);process.exit(2);});" || { echo "alter failed - reverting"; revert; exit 1; }

node --check lib/gszApi.js || { echo "gszApi syntax - reverting"; revert; exit 1; }
node --check routes/checkout.js || { echo "checkout syntax - reverting"; revert; exit 1; }
node --check lib/orderWorker.js || { echo "orderWorker syntax - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
pm2 restart zayron-orders >/dev/null 2>&1 || pm2 restart zayron-orders
HZ=000
for i in $(seq 1 15); do sleep 1; HZ=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:3500/" 2>/dev/null || echo 000); [ "$HZ" = "200" ] && break; done
echo "zayron / http=${HZ}"
[ "$HZ" = "200" ] || { echo "zayron not serving 200 - reverting"; revert; exit 1; }

echo "--- sending a TEST owner alert via the reseller bot /api/notify ---"
node -e "const g=require('/opt/zayron/lib/gszApi'); g.notify({event:'test', title:'🔔 Zayron owner alerts', message:'[TEST] Zayron owner order notifications are now live — you will get New / Delivered / Review alerts here.', text:'[TEST] Zayron owner order notifications are now live — you will get New / Delivered / Review alerts here.', ref:'TEST', order_no:'TEST', source:'zayron-web', site:'zayron.tv', at:new Date().toISOString()}).then(r=>console.log('notify ->', JSON.stringify(r))).catch(e=>console.log('notify ERR', e.message));" 2>&1 | tail -3
echo "DONE: zayron owner order notifications wired (New/Delivered/Review) via the reseller bot. zayron=${HZ}"
