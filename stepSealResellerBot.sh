#!/usr/bin/env bash
# stepSealResellerBot — stop the website handing the reseller bot a CUSTOMER's phone on fulfilment calls, so the bot
# can never message or register a website customer. Blanks userPhone/whatsapp on: galaxyzayron submitOrder (new+cart)
# and activatePlayer, and zayron submitOrder. The bot returns credentials by order ref, so the number isn't needed.
# verifyClaim (payment matching, never messages) and owner alerts (botapi.notify) are left intact. Renew already done.
# Safe: backup + single-match + revert + node --check + health loop on both apps (/ ==200).
set -e
TS=$(date +%s)
GSZ=/opt/gsz; ZAY=/opt/zayron
BG="$GSZ/.retired/$TS"; BZ="$ZAY/.retired/$TS"; mkdir -p "$BG" "$BZ"
cp "$GSZ/routes/checkout.js" "$BG/"; cp "$ZAY/lib/orderDispatch.js" "$BZ/"
revert(){ cp "$BG/checkout.js" "$GSZ/routes/checkout.js"; cp "$BZ/orderDispatch.js" "$ZAY/lib/orderDispatch.js"; pm2 restart gsz >/dev/null 2>&1 || true; pm2 restart zayron >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# ---- galaxyzayron: submitOrder #1 (new order) ----
cat > "$T/a_o" <<'O'
          ref: o.order_no, sku: o.bot_sku, quantity: o.qty || 1,
          userPhone: String(o.whatsapp || '').replace(/[^0-9]/g, ''),
O
cat > "$T/a_n" <<'O'
          ref: o.order_no, sku: o.bot_sku, quantity: o.qty || 1,
          userPhone: '',
O
# ---- galaxyzayron: submitOrder #2 (cart item) ----
cat > "$T/b_o" <<'O'
              ref, sku: it.bot_sku, quantity: it.qty || 1,
              userPhone: String(o.whatsapp || '').replace(/[^0-9]/g, ''),
O
cat > "$T/b_n" <<'O'
              ref, sku: it.bot_sku, quantity: it.qty || 1,
              userPhone: '',
O
# ---- galaxyzayron: activatePlayer ----
cat > "$T/c_o" <<'O'
            mac: mac,
            whatsapp: String(o.whatsapp || '').replace(/[^0-9]/g, ''),
            email: of.act_email || o.email || ''
O
cat > "$T/c_n" <<'O'
            mac: mac,
            whatsapp: '',
            email: of.act_email || o.email || ''
O
# ---- zayron: submitOrder ----
cat > "$T/z_o" <<'O'
    userPhone: o.phone || undefined, userName: o.name || undefined,
O
cat > "$T/z_n" <<'O'
    userPhone: undefined, userName: o.name || undefined,
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' matched x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('/opt/gsz/routes/checkout.js', [['a_o','a_n'],['b_o','b_n'],['c_o','c_n']]);
patch('/opt/zayron/lib/orderDispatch.js', [['z_o','z_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check "$GSZ/routes/checkout.js" || { echo "gsz syntax error - reverting"; revert; exit 1; }
node --check "$ZAY/lib/orderDispatch.js" || { echo "zayron syntax error - reverting"; revert; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HG=000; HZ=000
for i in $(seq 1 15); do sleep 1; HG=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:3900/" 2>/dev/null || echo 000); [ "$HG" = "200" ] && break; done
for i in $(seq 1 15); do sleep 1; HZ=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:3500/" 2>/dev/null || echo 000); [ "$HZ" = "200" ] && break; done
echo "gsz / http=${HG}   zayron / http=${HZ}"
[ "$HG" = "200" ] && [ "$HZ" = "200" ] || { echo "an app is not serving 200 - reverting"; revert; exit 1; }
echo "DONE: website no longer sends the reseller bot a customer phone on fulfilment (new orders, cart, player activation, renew — both sites). Owner alerts + payment verify intact. gsz=${HG} zayron=${HZ}"
