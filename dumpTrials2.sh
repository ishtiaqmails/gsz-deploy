#!/usr/bin/env bash
# dumpTrials2.sh — READ ONLY. The exact trial claim/generate flow, to pinpoint "text is not
# iterable" and see whether it passes plan_key/type for products whose bot record needs them.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "===== routes/trials.js : the POST claim handler (generate + response handling) ====="
ln=$(grep -nE "router\.post|generateTrial|needs|plan_key|bot_type|type\b" routes/trials.js | grep -iE "post|generateTrial" | head -1 | cut -d: -f1); ln=${ln:-100}
sed -n "${ln},$((ln+70))p" routes/trials.js

echo
echo "===== anything that spreads/iterates a 'text' value (the error source) ====="
grep -rnE "text|\[\.\.\.|for *\(.*of |Symbol\.iterator|\.map\(|split\(" routes/trials.js lib/trialpoll.js lib/deliveryMsg.js 2>/dev/null | grep -iE "text|\[\.\.\.| of " | head -25

echo
echo "===== how generate-trial payload is built (does it send plan_key/type?) ====="
grep -nE "generateTrial|plan_key|type|sku|hours|request_id|customer_ref|payload" routes/trials.js lib/trialpoll.js 2>/dev/null | grep -iE "generateTrial|plan_key|type|payload|request_id" | head -25

echo
echo "===== deliveryMsg.compose : does it iterate response fields (details/players)? ====="
grep -nE "function compose|details|players|fields|for *\(|\.map\(|\[\.\.\.|iterable" lib/deliveryMsg.js 2>/dev/null | head -25
