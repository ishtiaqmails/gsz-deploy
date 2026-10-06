#!/usr/bin/env bash
# step87 — Phase 3b-i: customer order notifications. Hooks notifyOrder() so it
# first enqueues a WhatsApp message to the (verified) customer for new/paid/
# delivered, independent of the owner bot. Uses the proven outbox + templates.
# One-place hook -> covers every existing call site. Idempotent; rolls back.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step87-$TS
mkdir -p "$BAK/routes"
cp "$APP/routes/checkout.js" "$BAK/routes/checkout.js"
restore(){ echo "!! rollback"; cp "$BAK/routes/checkout.js" "$APP/routes/checkout.js"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR
cd "$APP"

echo "==> patch checkout.js (notifyCustomerWa hook)"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/routes/checkout.js'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf('notifyCustomerWa')>=0){ console.log('   already patched'); process.exit(0); }
const a1="  const router = express.Router();";
if(s.indexOf(a1)<0){ console.error('!! router anchor not found'); process.exit(2); }
s=s.replace(a1, a1+"\n  const wanotify = require('../lib/wanotify')(pool);");
const a2="  async function notifyOrder(o, event) {\n    try {";
if(s.indexOf(a2)<0){ console.error('!! notifyOrder anchor not found'); process.exit(3); }
const block="  async function notifyCustomerWa(o, event) {\n"
 +"    if (!o || !o.customer_id) return;\n"
 +"    const map = { 'new':'whatsapp.order_received', 'paid':'whatsapp.payment_confirmed', 'delivered':'whatsapp.order_completed' };\n"
 +"    const tplKey = map[event]; if (!tplKey) return;\n"
 +"    const en = (await pool.query(\"SELECT value FROM wa_settings WHERE key='wa_order_notifications_enabled'\")).rows[0];\n"
 +"    if (en && en.value === '0') return;\n"
 +"    const link = (await pool.query(\"SELECT whatsapp_identity_id FROM customer_whatsapp_links WHERE customer_id=$1 AND status='ACTIVE' AND is_primary=true LIMIT 1\", [o.customer_id])).rows[0];\n"
 +"    if (!link) return;\n"
 +"    const cust = (await pool.query('SELECT ref_code FROM customers WHERE id=$1', [o.customer_id])).rows[0] || {};\n"
 +"    await wanotify.enqueue({ customer_id:o.customer_id, order_id:o.id, destination_identity_id:link.whatsapp_identity_id, template_key:tplKey, vars:{ site_name:'Galaxy Subz \\u00d7 Zayron', order_number:o.order_no||'', product_name:o.product_name||'', customer_reference:cust.ref_code||'' }, idempotency_key:'ord-'+o.id+'-'+event });\n"
 +"  }\n"
 +"  async function notifyOrder(o, event) {\n    try { await notifyCustomerWa(o, event); } catch (e) {}\n    try {";
s=s.replace(a2, block);
fs.writeFileSync(f,s); console.log('   checkout.js patched (customer order notifications)');
NODE

echo "==> node --check + restart"; node --check "$APP/routes/checkout.js"; pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }
C2=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://127.0.0.1:3900/order/GSZ-0000" || true)
echo "   /order route reachable (HTTP $C2)"
trap - ERR
echo "==> step87 OK — verified customers now get WhatsApp updates on new/paid/delivered. Backup: $BAK"
