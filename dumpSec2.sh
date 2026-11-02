#!/usr/bin/env bash
# dumpSec2.sh — READ ONLY. The two potential HIGH findings: (1) IDOR on the order-credentials
# route, (2) whether the full wa_settings (incl. google_sa_json private key, webhook secret)
# is ever sent to a browser/response.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "===== (1) the /account/order/:order_no/credentials route — does it verify ownership? ====="
f=$(grep -rlE "order_no.*credentials|/credentials|:order_no" routes/*.js 2>/dev/null | grep -vE '\.bak' | head -3)
for file in $f; do
  ln=$(grep -nE "credentials'|/credentials|:order_no|:ref" "$file" | head -1 | cut -d: -f1); [ -z "$ln" ] && continue
  echo "--- $file around line $ln ---"
  sed -n "$((ln>6?ln-6:1)),$((ln+34))p" "$file"
done

echo
echo "===== (1b) every route that serves order credentials/details — ownership WHERE clause? ====="
grep -rnE "delivered_credentials|/credentials|order.*WHERE.*order_no|FROM orders WHERE order_no" routes/*.js 2>/dev/null | grep -vE '\.bak' | grep -iE "order_no|credentials|customer_id|session" | head -20

echo
echo "===== (2) wabot.js / whatsapp.js — is the full settings object sent to a response/render? ====="
grep -nE "res\.(json|render|send)|waSettings\(|settings\(\)|google_sa_json|webhook_secret|cfg\b" routes/wabot.js 2>/dev/null | head -25
echo "--- whatsapp.js (webhook) ---"
grep -nE "res\.(json|render|send)|settings\(\)|google_sa_json|webhook_secret|auth|verify" routes/whatsapp.js 2>/dev/null | head -15

echo
echo "===== (2b) does the admin wabot VIEW print raw settings values? (would expose the key) ====="
grep -rnE "google_sa_json|wa_bot_webhook_secret|settings\[|<%= *s\.|<%- *s\.|JSON.stringify\(s" views/admin/wabot.ejs 2>/dev/null | head -15
echo "  (empty = the key is not printed into the page)"
