#!/usr/bin/env bash
# stepLifecycleMsg.sh — rewrite the lifecycle WhatsApp templates in the premium voice.
# DB rows only (wa_templates); old bodies saved to a backup JSON; restore with stepPreMsgRestore.sh.
set -euo pipefail
GSZ=/opt/gsz; TS=$(date +%Y%m%d-%H%M%S); BK="$GSZ/.bak-lifecycle-$TS"
mkdir -p "$BK"
cat > /tmp/lifecycle_update.js <<'JS'
const R='/opt/gsz'; require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const { Pool } = require(R+'/node_modules/pg'); const fs = require('fs');
const pool = new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
const T = {
  'whatsapp.order_received': [
    '🧾 *Order received* — {{order_number}}',
    '_{{site_name}}_',
    '',
    "We've got your order and we're on it. You'll get an update here at every step."
  ].join('\n'),
  'whatsapp.payment_confirmed': [
    '💰 *Payment confirmed* — {{order_number}}',
    '',
    "Thank you! We're preparing your order now — it'll arrive here shortly."
  ].join('\n'),
  'whatsapp.order_completed': [
    '🎉 *Order complete* — {{order_number}}',
    '',
    '{{product_name}} is ready. Check the details we sent you, and reply here if you need anything.'
  ].join('\n'),
  'whatsapp.trial_ready': [
    '🎁 *Your free trial is ready*',
    '{{server_name}} · {{duration_label}}',
    '',
    '{{credentials}}',
    '',
    '🔐 Open it anytime: {{secure_link}}',
    'Enjoying it? Reply here to upgrade to a full plan.'
  ].join('\n'),
  'whatsapp.subscription_expiry': [
    '⏰ *Renewal reminder*',
    '',
    'Your {{product_name}} expires on *{{expiry_date}}*.',
    'Renew in a tap to keep it active — just reply here.'
  ].join('\n'),
  'whatsapp.verification_success': [
    "✅ *You're verified*",
    '_{{site_name}}_',
    '',
    'Your WhatsApp is connected — order updates and trial details arrive right here.'
  ].join('\n'),
  'whatsapp.restock': [
    '📦 *Back in stock*',
    '{{product_name}} — {{plan_label}}',
    '',
    "It's available again — grab it before it's gone:",
    '{{link}}'
  ].join('\n')
};
(async () => {
  const bk = {};
  for (const k of Object.keys(T)) { const r = await pool.query('SELECT body FROM wa_templates WHERE key=$1', [k]); bk[k] = r.rows[0] ? r.rows[0].body : null; }
  fs.writeFileSync(process.argv[2], JSON.stringify(bk, null, 2));
  let n = 0;
  for (const k of Object.keys(T)) { await pool.query("INSERT INTO wa_templates(key,body) VALUES($1,$2) ON CONFLICT (key) DO UPDATE SET body=EXCLUDED.body", [k, T[k]]); n++; }
  console.log('   updated ' + n + ' lifecycle templates');
  await pool.end();
})().catch(e => { console.error(e.message); process.exit(1); });
JS
node /tmp/lifecycle_update.js "$BK/wa_templates.bak.json"
echo "DONE — lifecycle templates are premium. Backup: $BK/wa_templates.bak.json"
echo "       (restore: bash stepPreMsgRestore.sh $BK/wa_templates.bak.json ; then pm2 restart gsz)"
