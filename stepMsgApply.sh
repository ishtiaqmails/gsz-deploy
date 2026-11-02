#!/usr/bin/env bash
# stepMsgApply.sh — apply approved premium bot messages. whatsapp.js (help/menu/orders/5 verify replies) + 2 DB templates.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=routes/whatsapp.js
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back whatsapp.js"; cp -f "$F.xbak.$TS" "$F"; rm -f .olds.txt .news.txt .pair.js .tpl.js; exit 1; }
trap restore ERR
nchk(){ local i; for i in 1 2 3 4 5; do node --check "$F" 2>/dev/null && return 0; sleep 1; done; echo "  node --check failing"; return 1; }

cat > .olds.txt <<'OLDS'
      return ['👑 Owner commands', '', '• stock — all own-stock (or: stock <name>)', '• orders — today’s orders', '• order <no> — one order’s details', '• addstock <planId> then one unit per line', '• price <product> [plan] [country] — what a country sees', '', '(Only your owner number can use these.)'].join('\n');
@@@
return ['🛒 Choose a product to sell', ''].concat(lines).concat(['', 'Reply with the number (or cancel).']).join('\n');
@@@
return ['📊 Today', '', 'Orders: ' + tot.n
@@@
reply: 'Thanks — your reply has been added to your request ✅. Our team will respond shortly. You can also view the full conversation in your account: https://galaxyzayron.store/account' });
@@@
reply: 'This verification code is invalid or has already been used. Please start again from the website.' });
@@@
reply: 'This verification code has expired. Please start again from the website.' });
@@@
reply: 'This WhatsApp is already linked to another account. Please contact support if this is you.' });
@@@
reply: 'Your account already has a verified WhatsApp. Use "Change WhatsApp" on the website to switch numbers.' });
OLDS

cat > .news.txt <<'NEWS'
      return ['👑 Galaxy Subz × Zayron — Owner Console', '', '🛒 Sell', '• menu — guided sell (pick → quantity → deliver)', '• sell <id> — sell one unit of a plan', '• addstock <id> — add stock, then one unit per line', '', '📦 Catalogue', '• find [name] — browse products + prices', '• plans <id|name> — a product’s plans + prices', '• stock [name] — own-stock availability', '• price <product> [plan] [country] — what a country pays', '', '📊 Orders', '• orders — today’s totals + latest', '• order <no> — one order’s full detail', '', 'Type cancel anytime · Owner-only · galaxyzayron.store'].join('\n');
@@@
return ['🛒 Sell — choose a product', ''].concat(lines).concat(['', 'Reply with the number, or cancel.']).join('\n');
@@@
return ['📊 Today · galaxyzayron.store', '', 'Orders: ' + tot.n
@@@
reply: 'Thanks — your reply has been added to your request ✅.\n\nOur team will get back to you shortly. You can view the full conversation anytime in your account:\nhttps://galaxyzayron.store/account' });
@@@
reply: 'This verification code is invalid or already used.\n\nPlease start again from your account:\nhttps://galaxyzayron.store/account' });
@@@
reply: 'This verification code has expired.\n\nPlease request a fresh code from your account:\nhttps://galaxyzayron.store/account' });
@@@
reply: 'This WhatsApp is already linked to another account.\n\nIf this is you, please contact support:\n🌐 galaxyzayron.store' });
@@@
reply: 'Your account already has a verified WhatsApp.\n\nUse "Change WhatsApp" on the site to switch numbers:\nhttps://galaxyzayron.store/account' });
NEWS

cat > .pair.js <<'JS'
var fs = require('fs');
var olds = fs.readFileSync('.olds.txt', 'utf8').replace(/\n$/, '').split('\n@@@\n');
var news = fs.readFileSync('.news.txt', 'utf8').replace(/\n$/, '').split('\n@@@\n');
if (olds.length !== news.length) { console.log('pair count mismatch ' + olds.length + '/' + news.length); process.exit(2); }
var s = fs.readFileSync('routes/whatsapp.js', 'utf8');
for (var k = 0; k < olds.length; k++) { var a = olds[k], b = news[k]; var n = s.split(a).length - 1; if (n !== 1) { console.log('  pair ' + (k + 1) + ' x' + n + ' :: ' + a.slice(0, 60)); process.exit(2); } s = s.split(a).join(b); console.log('  pair ' + (k + 1) + ': ok'); }
fs.writeFileSync('routes/whatsapp.js', s);
console.log('  whatsapp.js patched');
process.exit(0);
JS
echo "==> patching whatsapp.js messages"
node .pair.js
nchk
echo "   node check ok"
trap - ERR

echo "==> updating 2 DB templates (English body + langs.en; other languages untouched)"
cat > .tpl.js <<'JS'
require('/opt/gsz/node_modules/dotenv').config({ path: '/opt/gsz/.env' });
const { Pool } = require('/opt/gsz/node_modules/pg');
const p = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });
const redirect = `This number is for website verification & account security only.

For orders & help:
🌐 galaxyzayron.store
💬 Sales: https://wa.me/{{sales_number}}
🛟 Support: https://wa.me/{{support_number}}`;
const verified = `✅ *You're verified* — {{site_name}}

Your WhatsApp is connected. Order updates and trial details arrive right here.

🌐 galaxyzayron.store`;
(async () => {
  try {
    await p.query("UPDATE wa_templates SET body=$1, langs=jsonb_set(COALESCE(langs,'{}'::jsonb),'{en}',to_jsonb($1::text)), updated_at=now() WHERE key='whatsapp.redirect_support'", [redirect]);
    await p.query("UPDATE wa_templates SET body=$1, langs=jsonb_set(COALESCE(langs,'{}'::jsonb),'{en}',to_jsonb($1::text)), updated_at=now() WHERE key='whatsapp.verification_success'", [verified]);
    console.log('  templates updated: redirect_support, verification_success');
  } catch (e) { console.log('  tpl err: ' + e.message); }
  await p.end();
})();
JS
node .tpl.js
rm -f .olds.txt .news.txt .pair.js .tpl.js

echo "==> restart site + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
echo "DONE — premium help + menu + orders + customer verify replies + 2 templates live."
