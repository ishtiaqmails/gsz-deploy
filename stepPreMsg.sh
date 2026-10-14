#!/usr/bin/env bash
# stepPreMsg.sh — premium WhatsApp delivery (main) + separate Instructions & Warranty follow-up.
#   1) patch lib/deliver.js (adds purchase date + plan to delivery; warranty into the follow-up)
#   2) rewrite wa_templates whatsapp.credentials + whatsapp.instructions (old bodies backed up)
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-premsg-$TS"; cd "$GSZ"
DV=lib/deliver.js
mkdir -p "$BK/lib"; cp "$GSZ/$DV" "$BK/$DV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring deliver.js"; cp "$BK/$DV" "$GSZ/$DV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> 1) patch lib/deliver.js"
node "$SRC/patch_premsg.js" "$GSZ"
node --check "$GSZ/$DV" && echo "   deliver.js ok"

echo "==> 2) rewrite the two templates (old bodies -> $BK/wa_templates.bak.json)"
cat > /tmp/premsg_update.js <<'JS'
const R='/opt/gsz'; require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const { Pool } = require(R+'/node_modules/pg'); const fs = require('fs');
const pool = new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
const CRED = [
  '━━━━━━━━━━━━━━',
  '✅ *ORDER DELIVERED*',
  '_{{site_name}}_',
  '━━━━━━━━━━━━━━',
  '',
  '📦 *{{product_name}}*',
  '🧾 Order  ·  {{order_number}}',
  '📅 Purchased  ·  {{order_date}}',
  '{{plan_line}}',
  '',
  '━━━  *YOUR LOGIN*  ━━━',
  '{{credentials}}',
  '━━━━━━━━━━━━━━',
  '',
  "💬 Need help? Just reply — we're on it.",
  'Thank you for choosing us.'
].join('\n');
const INSTR = [
  '━━━━━━━━━━━━━━',
  '📋 *{{product_name}}*',
  '_Instructions & Warranty_',
  '━━━━━━━━━━━━━━',
  '',
  '{{instructions_section}}{{warranty_section}}💬 Any issue? Reply here — we’re on it.'
].join('\n');
(async () => {
  const bk = {};
  for (const k of ['whatsapp.credentials','whatsapp.instructions']) {
    const r = await pool.query('SELECT body FROM wa_templates WHERE key=$1', [k]);
    bk[k] = r.rows[0] ? r.rows[0].body : null;
  }
  fs.writeFileSync(process.argv[2], JSON.stringify(bk, null, 2));
  await pool.query('UPDATE wa_templates SET body=$1 WHERE key=$2', [CRED, 'whatsapp.credentials']);
  await pool.query('UPDATE wa_templates SET body=$1 WHERE key=$2', [INSTR, 'whatsapp.instructions']);
  console.log('   templates updated (credentials + instructions)');
  await pool.end();
})().catch(e => { console.error(e.message); process.exit(1); });
JS
node /tmp/premsg_update.js "$BK/wa_templates.bak.json"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — premium WhatsApp delivery live (main message + separate Instructions & Warranty)"
echo "       template backup: $BK/wa_templates.bak.json  (restore: bash stepPreMsgRestore.sh $BK/wa_templates.bak.json)"
