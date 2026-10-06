#!/usr/bin/env bash
# step85 — Phase 3a: link orders to the customer account + show them on the
# dashboard. Adds orders.customer_id, stamps it at checkout (single + cart)
# when a customer is logged in, queries the customer's orders, and renders them.
# Idempotent; rolls back checkout.js, account.js, dashboard.ejs.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step85-$TS
mkdir -p "$BAK/routes" "$BAK/views/account"
cp "$APP/routes/checkout.js" "$BAK/routes/checkout.js"
cp "$APP/routes/account.js" "$BAK/routes/account.js"
cp "$APP/views/account/dashboard.ejs" "$BAK/views/account/dashboard.ejs"
restore(){ echo "!! rollback"; cp "$BAK/routes/checkout.js" "$APP/routes/checkout.js"; cp "$BAK/routes/account.js" "$APP/routes/account.js"; cp "$BAK/views/account/dashboard.ejs" "$APP/views/account/dashboard.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR
cd "$APP"

echo "==> migrate: orders.customer_id"
node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{
  await p.query("ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_id integer REFERENCES customers(id) ON DELETE SET NULL");
  await p.query("CREATE INDEX IF NOT EXISTS orders_customer_idx ON orders(customer_id)");
  await p.query("CREATE INDEX IF NOT EXISTS orders_email_lower_idx ON orders(lower(email))");
  console.log('   orders.customer_id ready');
  await p.end();
})().catch(e=>{ console.error('MIGRATION FAIL: '+e.message); process.exit(1); });
NODE

echo "==> patch checkout.js (stamp customer_id on both inserts)"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/routes/checkout.js'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf(',bot_type,fields,customer_id)')>=0){ console.log('   checkout.js already patched'); }
else {
  const colOld=',bot_type,fields)', colNew=',bot_type,fields,customer_id)';
  const valOld=',$22) RETURNING id', valNew=',$22,$23) RETURNING id';
  const singleOld='JSON.stringify(fields)]', singleNew="JSON.stringify(fields), (req.session && req.session.customer ? req.session.customer.id : null)]";
  const cartOld='JSON.stringify({ items, screenshotHash })]', cartNew="JSON.stringify({ items, screenshotHash }), (req.session && req.session.customer ? req.session.customer.id : null)]";
  [colOld,valOld,singleOld,cartOld].forEach(t=>{ if(s.indexOf(t)<0){ console.error('!! anchor not found: '+t); process.exit(2); } });
  s=s.split(colOld).join(colNew);
  s=s.split(valOld).join(valNew);
  s=s.replace(singleOld, singleNew);
  s=s.replace(cartOld, cartNew);
  fs.writeFileSync(f,s); console.log('   checkout.js patched');
}
NODE

echo "==> patch account.js (query customer orders)"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/routes/account.js'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf('/*ordersLink*/')>=0){ console.log('   account.js already patched'); }
else {
  const anc="    res.render('account/dashboard', Object.assign(await shell(), { title: 'My account', c, ok: req.query.ok || null, wa }));";
  if(s.indexOf(anc)<0){ console.error('!! account render anchor not found'); process.exit(3); }
  const repl="    let orders=[]; /*ordersLink*/\n    try{ orders=(await pool.query(\"SELECT id, order_no, status, product_name, plan_label, amount_display, currency, created_at FROM orders WHERE customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2)) ORDER BY id DESC LIMIT 8\",[c.id, c.email])).rows; }catch(e){}\n    res.render('account/dashboard', Object.assign(await shell(), { title: 'My account', c, ok: req.query.ok || null, wa, orders }));";
  s=s.replace(anc, repl); fs.writeFileSync(f,s); console.log('   account.js patched');
}
NODE

echo "==> overwrite dashboard.ejs"
base64 -d > "$APP/views/account/dashboard.ejs" <<'B64'
PCUtIGluY2x1ZGUoJy4uL3BhcnRpYWxzL3N0b3JlX3RvcCcpICU+CjwlLSBpbmNsdWRlKCcuLi9wYXJ0aWFscy9hdXRoX3N0eWxlJykgJT4KPCUgdmFyIHdhT2sgPSAodHlwZW9mIHdhIT09J3VuZGVmaW5lZCcgJiYgd2EgJiYgd2EudmVyaWZpZWQpOyB2YXIgd2FQaG9uZSA9ICh0eXBlb2Ygd2EhPT0ndW5kZWZpbmVkJyAmJiB3YSkgPyAod2EucGhvbmV8fCcnKSA6ICcnOwogICB2YXIgb3JkcyA9ICh0eXBlb2Ygb3JkZXJzIT09J3VuZGVmaW5lZCcgJiYgb3JkZXJzKSA/IG9yZGVycyA6IFtdOwogICBmdW5jdGlvbiBzdENscyhzKXsgcz1TdHJpbmcoc3x8JycpLnRvTG93ZXJDYXNlKCk7IGlmKHM9PT0nZGVsaXZlcmVkJ3x8cz09PSdjb21wbGV0ZWQnfHxzPT09J2RvbmUnKSByZXR1cm4gJ29rJzsgaWYocz09PSdyZWplY3RlZCd8fHM9PT0nZmFpbGVkJ3x8cz09PSdjYW5jZWxsZWQnKSByZXR1cm4gJ2JhZCc7IHJldHVybiAnbm8nOyB9CiAgIGZ1bmN0aW9uIG1vbmV5KG8peyB2YXIgYz0oby5jdXJyZW5jeXx8JycpLnRvVXBwZXJDYXNlKCk7IHZhciBhPW8uYW1vdW50X2Rpc3BsYXkhPW51bGw/by5hbW91bnRfZGlzcGxheTowOyB2YXIgbj1NYXRoLnJvdW5kKE51bWJlcihhKSkudG9Mb2NhbGVTdHJpbmcoJ2VuLVVTJyk7IHJldHVybiBjPT09J1VTRCc/KCckJytuKTooYz09PSdQS1InPygnUnMgJytuKTooYz9jKycgJytuOm4pKTsgfQolPgo8bWFpbiBjbGFzcz0iZGFzaCI+CiAgPGRpdiBjbGFzcz0id3JhcCI+CiAgICA8ZGl2IGNsYXNzPSJkYXNoLWhlYWQiPgogICAgICA8ZGl2PgogICAgICAgIDxoMT5IaSwgPCU9IChjLm5hbWV8fCd0aGVyZScpLnNwbGl0KCcgJylbMF0gJT48L2gxPgogICAgICAgIDxwIGNsYXNzPSJzdWIiPldlbGNvbWUgdG8geW91ciBhY2NvdW50LjwvcD4KICAgICAgPC9kaXY+CiAgICAgIDxmb3JtIG1ldGhvZD0icG9zdCIgYWN0aW9uPSIvbG9nb3V0IiBzdHlsZT0ibWFyZ2luOjAiPjxidXR0b24gY2xhc3M9ImJ0biBidG4tZyIgdHlwZT0ic3VibWl0Ij5TaWduIG91dDwvYnV0dG9uPjwvZm9ybT4KICAgIDwvZGl2PgoKICAgIDwlIGlmIChvayA9PT0gJ2VtYWlsJykgeyAlPjxkaXYgY2xhc3M9Im9rbXNnIiBzdHlsZT0ibWF4LXdpZHRoOjc2MHB4Ij5Zb3VyIGVtYWlsIGlzIHZlcmlmaWVkIOKAlCB5b3UncmUgYWxsIHNldC48L2Rpdj48JSB9ICU+CgogICAgPGRpdiBjbGFzcz0iZGFzaC1ncmlkIj4KICAgICAgPGRpdiBjbGFzcz0iZGFzaC1jYXJkIj4KICAgICAgICA8aDI+WW91ciBwcm9maWxlPC9oMj4KICAgICAgICA8ZGl2IGNsYXNzPSJkcm93Ij48c3BhbiBjbGFzcz0iayI+TmFtZTwvc3Bhbj48c3BhbiBjbGFzcz0idiI+PCU9IGMubmFtZSAlPjwvc3Bhbj48L2Rpdj4KICAgICAgICA8ZGl2IGNsYXNzPSJkcm93Ij48c3BhbiBjbGFzcz0iayI+RW1haWw8L3NwYW4+PHNwYW4gY2xhc3M9InYiPgogICAgICAgICAgPCU9IGMuZW1haWwgJT4KICAgICAgICAgIDwlIGlmIChjLmVtYWlsX3ZlcmlmaWVkKSB7ICU+PHNwYW4gY2xhc3M9InZiYWRnZSBvayIgc3R5bGU9Im1hcmdpbi1sZWZ0OjhweCI+VmVyaWZpZWQ8L3NwYW4+CiAgICAgICAgICA8JSB9IGVsc2UgeyAlPjxhIGhyZWY9Ii9hY2NvdW50L3ZlcmlmeS1lbWFpbCIgY2xhc3M9InZiYWRnZSBubyIgc3R5bGU9Im1hcmdpbi1sZWZ0OjhweDt0ZXh0LWRlY29yYXRpb246bm9uZSI+VmVyaWZ5IG5vdzwvYT48JSB9ICU+CiAgICAgICAgPC9zcGFuPjwvZGl2PgogICAgICAgIDxkaXYgY2xhc3M9ImRyb3ciPjxzcGFuIGNsYXNzPSJrIj5XaGF0c0FwcDwvc3Bhbj48c3BhbiBjbGFzcz0idiI+CiAgICAgICAgICA8JSBpZiAod2FPaykgeyAlPjwlPSB3YVBob25lID8gd2FQaG9uZSA6IChjLndhX251bWJlciA/ICgnKycrYy53YV9udW1iZXIpIDogJycpICU+IDxzcGFuIGNsYXNzPSJ2YmFkZ2Ugb2siIHN0eWxlPSJtYXJnaW4tbGVmdDo4cHgiPlZlcmlmaWVkPC9zcGFuPgogICAgICAgICAgPCUgfSBlbHNlIHsgJT48YSBocmVmPSIvYWNjb3VudC93aGF0c2FwcCIgY2xhc3M9InZiYWRnZSBubyIgc3R5bGU9Im1hcmdpbi1sZWZ0OjhweDt0ZXh0LWRlY29yYXRpb246bm9uZSI+VmVyaWZ5IFdoYXRzQXBwPC9hPjwlIH0gJT4KICAgICAgICA8L3NwYW4+PC9kaXY+CiAgICAgIDwvZGl2PgoKICAgICAgPGRpdiBjbGFzcz0iZGFzaC1jYXJkIj4KICAgICAgICA8aDI+V2hhdHNBcHA8L2gyPgogICAgICAgIDwlIGlmICh3YU9rKSB7ICU+CiAgICAgICAgICA8cCBjbGFzcz0ic29vbiI+WW91ciBXaGF0c0FwcCBpcyB2ZXJpZmllZC4gWW91J2xsIGdldCBvcmRlciB1cGRhdGVzIGFuZCBsb2dpbiBkZXRhaWxzIHRoZXJlLCBhbmQgeW91IGNhbiBjbGFpbSBmcmVlIHRyaWFscy4gPGEgaHJlZj0iL2FjY291bnQvd2hhdHNhcHAiIHN0eWxlPSJjb2xvcjp2YXIoLS1iKTtmb250LXdlaWdodDo2MDAiPk1hbmFnZSDihpI8L2E+PC9wPgogICAgICAgIDwlIH0gZWxzZSB7ICU+CiAgICAgICAgICA8cCBjbGFzcz0ic29vbiIgc3R5bGU9Im1hcmdpbi1ib3R0b206MTRweCI+VmVyaWZ5IHlvdXIgV2hhdHNBcHAgdG8gZ2V0IGluc3RhbnQgb3JkZXIgdXBkYXRlcyBhbmQgdG8gdW5sb2NrIGZyZWUgSVBUViB0cmlhbHMuIE9uZSB0YXAg4oCUIG5vIG5lZWQgdG8gdHlwZSB5b3VyIG51bWJlci48L3A+CiAgICAgICAgICA8YSBjbGFzcz0iYnRuIGJ0bi1wIiBocmVmPSIvYWNjb3VudC93aGF0c2FwcCI+VmVyaWZ5IHdpdGggV2hhdHNBcHA8L2E+CiAgICAgICAgPCUgfSAlPgogICAgICA8L2Rpdj4KCiAgICAgIDxkaXYgY2xhc3M9ImRhc2gtY2FyZCI+CiAgICAgICAgPGgyPllvdXIgb3JkZXJzPC9oMj4KICAgICAgICA8JSBpZiAoIW9yZHMubGVuZ3RoKSB7ICU+CiAgICAgICAgICA8cCBjbGFzcz0ic29vbiI+Tm8gb3JkZXJzIHlldC4gPGEgaHJlZj0iLyIgc3R5bGU9ImNvbG9yOnZhcigtLWIpO2ZvbnQtd2VpZ2h0OjYwMCI+QnJvd3NlIHByb2R1Y3RzIOKGkjwvYT48L3A+CiAgICAgICAgPCUgfSBlbHNlIHsgJT4KICAgICAgICAgIDwlIG9yZHMuZm9yRWFjaChmdW5jdGlvbihvKXsgJT4KICAgICAgICAgICAgPGEgY2xhc3M9ImRyb3ciIHN0eWxlPSJ0ZXh0LWRlY29yYXRpb246bm9uZTtnYXA6MTBweCIgaHJlZj0iPCU9IG8ub3JkZXJfbm8gPyAoJy9vcmRlci8nK28ub3JkZXJfbm8pIDogJyMnICU+Ij4KICAgICAgICAgICAgICA8c3BhbiBjbGFzcz0iayIgc3R5bGU9ImZsZXg6MTttaW4td2lkdGg6MCI+CiAgICAgICAgICAgICAgICA8c3BhbiBzdHlsZT0iY29sb3I6dmFyKC0taW5rKTtmb250LXdlaWdodDo2MDA7ZGlzcGxheTpibG9jazt3aGl0ZS1zcGFjZTpub3dyYXA7b3ZlcmZsb3c6aGlkZGVuO3RleHQtb3ZlcmZsb3c6ZWxsaXBzaXMiPjwlPSBvLnByb2R1Y3RfbmFtZSB8fCAnT3JkZXInICU+PC9zcGFuPgogICAgICAgICAgICAgICAgPHNwYW4gc3R5bGU9ImZvbnQtc2l6ZToxMi41cHgiPjwlPSBvLm9yZGVyX25vIHx8ICgnIycrby5pZCkgJT48JT0gby5wbGFuX2xhYmVsID8gKCcgwrcgJytvLnBsYW5fbGFiZWwpIDogJycgJT48L3NwYW4+CiAgICAgICAgICAgICAgPC9zcGFuPgogICAgICAgICAgICAgIDxzcGFuIGNsYXNzPSJ2IiBzdHlsZT0idGV4dC1hbGlnbjpyaWdodDt3aGl0ZS1zcGFjZTpub3dyYXAiPgogICAgICAgICAgICAgICAgPHNwYW4gc3R5bGU9ImRpc3BsYXk6YmxvY2siPjwlPSBtb25leShvKSAlPjwvc3Bhbj4KICAgICAgICAgICAgICAgIDxzcGFuIGNsYXNzPSJ2YmFkZ2UgPCU9IHN0Q2xzKG8uc3RhdHVzKSAlPiIgc3R5bGU9Im1hcmdpbi10b3A6NHB4Ij48JT0gKG8uc3RhdHVzfHwncGVuZGluZycpICU+PC9zcGFuPgogICAgICAgICAgICAgIDwvc3Bhbj4KICAgICAgICAgICAgPC9hPgogICAgICAgICAgPCUgfSk7ICU+CiAgICAgICAgPCUgfSAlPgogICAgICA8L2Rpdj4KCiAgICAgIDxkaXYgY2xhc3M9ImRhc2gtY2FyZCI+CiAgICAgICAgPGgyPkZyZWUgdHJpYWxzPC9oMj4KICAgICAgICA8cCBjbGFzcz0ic29vbiI+RWxpZ2libGUgSVBUViB0cmlhbHMgd2lsbCBhcHBlYXIgaGVyZS4gPCU9IHdhT2sgPyAnWW91ciBXaGF0c0FwcCBpcyB2ZXJpZmllZCDigJQgeW91IGNhbiBjbGFpbSB0cmlhbHMgd2hlbiB0aGV5IGdvIGxpdmUuJyA6ICdWZXJpZnkgeW91ciBXaGF0c0FwcCB0byB1bmxvY2sgdGhlbS4nICU+PC9wPgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogIDwvZGl2Pgo8L21haW4+CjwlLSBpbmNsdWRlKCcuLi9wYXJ0aWFscy9zdG9yZV9ib3R0b20nKSAlPgo=
B64

echo "==> node --check + ejs compile"
node --check "$APP/routes/checkout.js"; node --check "$APP/routes/account.js"
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$APP/views/account/dashboard.ejs','utf8'),{filename:'x'});console.log('   dashboard compiles');"

echo "==> restart + health"; pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }
C1=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:3900/account || true)
[ "$C1" = "302" ] || { echo "!! /account should redirect when signed out (got $C1)"; false; }
C2=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:3900/checkout || true)
echo "   /checkout -> HTTP $C2 (should be 200/302, i.e. still works)"
trap - ERR
echo "==> step85 OK — orders linked to accounts + shown on dashboard. Backup: $BAK"
echo "   New orders placed while logged in will appear under My account."
