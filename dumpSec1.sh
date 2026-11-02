#!/usr/bin/env bash
# dumpSec1.sh — READ ONLY security review of the money paths + access control.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "===== CHECKOUT: is the order amount recomputed server-side or trusted from the client? ====="
grep -nE "req\.(body|query|params)\.(amount|price|total|plan|region|type|sku|p)\b|amount|price_pkr|from_usd|INSERT INTO orders|computePrice|resolve\(|gsz_pricing|plan_label|region" routes/checkout.js 2>/dev/null | grep -ivE '\.bak' | head -45

echo
echo "===== ORDER/CREDENTIAL ACCESS: is it scoped to the logged-in customer? (IDOR check) ====="
grep -nE "order_no|credentials|customer_id|req\.session|WHERE|/order/|/credentials|params\.(order_no|id)" routes/account.js 2>/dev/null | grep -iE "credential|order_no|customer_id|session|/order" | head -30

echo
echo "===== SESSION/COOKIE config (secure, httpOnly, sameSite) + any header hardening ====="
grep -nE "cookie|session\(|secure|httpOnly|sameSite|helmet|setHeader|Content-Security|maxAge|trust proxy" server.js 2>/dev/null | head -25

echo
echo "===== SQL INJECTION: any query built by string-concatenating request input? ====="
grep -rnE "query\(\s*[\`'\"][^)]*\+\s*(req\.|request\.)" routes lib 2>/dev/null | grep -vE '\.bak' | head -20
echo "  (empty above = no obvious concatenated-input queries)"

echo
echo "===== SECRETS: is wa_settings (holds google_sa_json / indexnow_key) exposed by any route? ====="
grep -rnE "wa_settings|google_sa_json|DB_PASS|GSZ_BOT_API_KEY|process\.env" routes 2>/dev/null | grep -iE "res\.(json|send)|SELECT .*wa_settings|value FROM wa_settings" | grep -vE '\.bak' | head -20
echo "  (look for any route that returns wa_settings rows or env to the client)"
