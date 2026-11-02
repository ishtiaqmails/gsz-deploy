#!/usr/bin/env bash
# stepMsgApply2.sh — premium messages, ASCII-only anchors (editor converts \u escapes, so avoid them). help via position.
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
Choose a product to sell
@@@
Reply with the number (or cancel).
@@@
 Today', '', 'Orders: ' + tot.n
@@@
Our team will respond shortly. You can also view the full conversation in your account: https://galaxyzayron.store/account
@@@
'This verification code is invalid or has already been used. Please start again from the website.'
@@@
'This verification code has expired. Please start again from the website.'
@@@
'This WhatsApp is already linked to another account. Please contact support if this is you.'
@@@
'Your account already has a verified WhatsApp. Use "Change WhatsApp" on the website to switch numbers.'
OLDS

cat > .news.txt <<'NEWS'
Sell — choose a product
@@@
Reply with the number, or cancel.
@@@
 Today · galaxyzayron.store', '', 'Orders: ' + tot.n
@@@
Our team will get back to you shortly. View the full conversation anytime: https://galaxyzayron.store/account
@@@
['This verification code is invalid or already used.','','Please start again from your account:','https://galaxyzayron.store/account'].join(String.fromCharCode(10))
@@@
['This verification code has expired.','','Please request a fresh code from your account:','https://galaxyzayron.store/account'].join(String.fromCharCode(10))
@@@
['This WhatsApp is already linked to another account.','','If this is you, please contact support:','🌐 galaxyzayron.store'].join(String.fromCharCode(10))
@@@
['Your account already has a verified WhatsApp.','','Use "Change WhatsApp" on the site to switch numbers:','https://galaxyzayron.store/account'].join(String.fromCharCode(10))
NEWS

cat > .pair.js <<'JS'
var fs = require('fs');
var s = fs.readFileSync('routes/whatsapp.js', 'utf8');
// 1) HELP — replace by position (ASCII markers only; immune to emoji/escape bytes)
var hm = "if (/^(help|menu|commands|cmd|owner)$/i.test(t)) {";
var hi = s.indexOf(hm);
if (hi < 0) { console.log('  help marker missing'); process.exit(2); }
var rs = s.indexOf('return [', hi);
var jo = s.indexOf('].join(', rs);
var semi = s.indexOf(';', jo);
if (rs < 0 || jo < 0 || semi < 0) { console.log('  help bounds missing'); process.exit(2); }
var newHelp = "return ['👑 Galaxy Subz × Zayron — Owner Console','','🛒 Sell','• menu — guided sell (pick → quantity → deliver)','• sell <id> — sell one unit of a plan','• addstock <id> — add stock, then one unit per line','','📦 Catalogue','• find [name] — browse products + prices','• plans <id|name> — plans + prices of a product','• stock [name] — own-stock availability','• price <product> [plan] [country] — what a country pays','','📊 Orders','• orders — today totals + latest','• order <no> — full order detail','','Type cancel anytime · Owner-only · galaxyzayron.store'].join(String.fromCharCode(10));";
s = s.slice(0, rs) + newHelp + s.slice(semi + 1);
console.log('  help: replaced');
// 2) ASCII string pairs
var olds = fs.readFileSync('.olds.txt', 'utf8').replace(/\n$/, '').split('\n@@@\n');
var news = fs.readFileSync('.news.txt', 'utf8').replace(/\n$/, '').split('\n@@@\n');
if (olds.length !== news.length) { console.log('  pair count mismatch ' + olds.length + '/' + news.length); process.exit(2); }
for (var k = 0; k < olds.length; k++) { var a = olds[k], b = news[k]; var n = s.split(a).length - 1; if (n !== 1) { console.log('  pair ' + (k + 1) + ' x' + n + ' :: ' + a.slice(0, 50)); process.exit(2); } s = s.split(a).join(b); console.log('  pair ' + (k + 1) + ': ok'); }
fs.writeFileSync('routes/whatsapp.js', s);
console.log('  whatsapp.js patched');
process.exit(0);
JS
echo "==> patching whatsapp.js messages"
node .pair.js
nchk
echo "   node check ok"
trap - ERR

echo "==> updating 2 DB templates (English body + langs.en; translations untouched)"
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
