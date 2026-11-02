#!/usr/bin/env bash
# stepBotDiag2.sh — READ ONLY. LIVE whatsapp.js owner wiring + product_plans price cols + DB config.
set -uo pipefail
GSZ=/opt/gsz; F=$GSZ/routes/whatsapp.js

echo "===== 1) LIVE whatsapp.js — owner wiring markers ====="
grep -n "ownerCommand\|isOwner\|_owners\|wa_owner_numbers\|wa_bot_send\|sendText\|wanotify\|_isOwner" "$F" 2>/dev/null | head -40

echo; echo "===== 2) the /internal/whatsapp/incoming POST handler (full) ====="
L=$(grep -n "router.post('/internal/whatsapp/incoming'\|'/internal/whatsapp/incoming'" "$F" 2>/dev/null | head -1 | cut -d: -f1)
echo "post handler near line: ${L:-<not found>}"
if [ -n "${L:-}" ]; then sed -n "$((L>5?L-5:1)),$((L+120))p" "$F"; fi

echo; echo "===== 3) product_plans columns incl price (from code) ====="
grep -rn "product_plans" "$GSZ/lib/storefront.js" 2>/dev/null | head -10
grep -rniE "price|price_pkr|price_usd|amount|pkr|usd" "$GSZ/lib/storefront.js" 2>/dev/null | head -15
echo "---- a representative plan SELECT in checkout/account ----"
grep -rn "FROM product_plans" "$GSZ/routes" "$GSZ/lib" --include=*.js 2>/dev/null | grep -v node_modules | head -8

echo; echo "===== 4) DB config (for later psql if needed) ====="
grep -n "new Pool\|connectionString\|database\|user\|host\|password" "$GSZ/server.js" 2>/dev/null | head -12
echo "DONE2"
