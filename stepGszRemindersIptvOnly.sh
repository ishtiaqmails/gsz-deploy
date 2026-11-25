#!/usr/bin/env bash
# stepGszRemindersIptvOnly — restrict galaxyzayron subscription-expiry/renewal reminders to IPTV products
# only (delivery_type='iptv'). Non-IPTV renewable products (HBO, Disney+, etc.) will no longer be reminded.
# One anchored edit in routes/checkout.js. Safe: backup, single-match + auto-revert, node --check, health loop.
# Also reports whether zayron.tv has its own reminder sender that needs the same change.
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp routes/checkout.js "$B/checkout.js.bak"
revert(){ cp "$B/checkout.js.bak" routes/checkout.js; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/o" <<'O'
      const rows = (await pool.query("SELECT id,order_no,product_id,product_name,customer_id,whatsapp,email,renew_reminded_exp FROM orders WHERE status='delivered' AND delivered_at > now() - interval '400 days' AND (customer_id IS NOT NULL OR (whatsapp IS NOT NULL AND whatsapp<>'')) AND product_id IN (SELECT id FROM products WHERE renewable IS TRUE) ORDER BY id DESC LIMIT 40")).rows;
O
cat > "$T/n" <<'O'
      const rows = (await pool.query("SELECT id,order_no,product_id,product_name,customer_id,whatsapp,email,renew_reminded_exp FROM orders WHERE status='delivered' AND delivered_at > now() - interval '400 days' AND (customer_id IS NOT NULL OR (whatsapp IS NOT NULL AND whatsapp<>'')) AND product_id IN (SELECT id FROM products WHERE renewable IS TRUE) AND product_id IN (SELECT DISTINCT pp.product_id FROM product_plans pp JOIN bot_products bp ON bp.sku=pp.bot_sku WHERE bp.delivery_type='iptv') ORDER BY id DESC LIMIT 40")).rows;
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('routes/checkout.js','utf8'); const O=rd('o'), N=rd('n'); const c=s.split(O).length-1;
if(c!==1){ console.error('ANCHOR x'+c); process.exit(5); }
fs.writeFileSync('routes/checkout.js', s.split(O).join(N)); console.log('routes/checkout.js PATCHED OK (reminders -> IPTV only)');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/checkout.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }

echo
echo "### does zayron.tv (/opt/zayron) have its own automated expiry/renewal reminder sender? ###"
cd /opt/zayron 2>/dev/null && grep -rn "setInterval\|subscription_expiry\|renew_remind\|expiry.*remind\|reminder\|expiring" --include=*.js lib routes server.js 2>/dev/null | grep -iE "remind|expiry|expiring" | grep -v node_modules | grep -v "\.bak" | head -20 || echo "(no zayron reminder matches)"
echo "DONE: galaxyzayron reminders now IPTV-only. gsz http=${HC}"
