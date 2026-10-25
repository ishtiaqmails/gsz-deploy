#!/usr/bin/env bash
# dumpCheckoutGate.sh — bounded, line-numbered dump of the checkout order-creation
#   handler + how deliver.js sends the delivery message. Read-only. Output kept small.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ # file start end
  awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%5d| %s\n",NR,$0}' "$1"
}

echo "###### 1) CHECKOUT ROUTE (order creation) ######"
F=$(grep -rl --include=*.js "startStatus = isFree" "$GSZ" 2>/dev/null | grep -v node_modules | head -1)
echo "FILE: $F"
if [ -n "$F" ]; then
  echo "--- identity / session / login refs in this file ---"
  grep -nE "req\.session|requireLogin|customer_id|res\.redirect\(.?/(login|account)|guest|wa_verified|isLoggedIn|\.customer\b|loginRequired" "$F" | head -40
  echo "--- order-insert window (real line numbers) ---"
  N=$(grep -n "startStatus = isFree" "$F" | head -1 | cut -d: -f1)
  S=$(( N>95 ? N-95 : 1 )); E=$(( N+45 ))
  win "$F" "$S" "$E"
fi

echo
echo "###### 2) DELIVER.JS — delivery message send ######"
D=$(ls "$GSZ"/lib/deliver.js "$GSZ"/routes/deliver.js "$GSZ"/deliver.js 2>/dev/null | head -1)
[ -z "$D" ] && D=$(grep -rl --include=*.js "deliveryMsg" "$GSZ" 2>/dev/null | grep -v node_modules | grep -i deliver | head -1)
echo "FILE: $D"
if [ -n "$D" ]; then
  echo "--- compose / mail / whatsapp / credentials refs ---"
  grep -nE "deliveryMsg|\.compose\(|wanotify|enqueue|sendMail|mailer|sendEmail|transporter|delivered_credentials|_m\.(main|followup|credentials)|customer_id|wa_number" "$D" | head -50
fi
echo
echo "== END DUMP =="
