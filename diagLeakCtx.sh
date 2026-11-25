#!/usr/bin/env bash
# diagLeakCtx — exact payload context for the ambiguous leaks (updateHousehold whatsapp, verifyClaim userPhone) +
# the exact submitOrder/activatePlayer payload lines to blank the customer phone precisely. READ-ONLY.
set +e
cd /opt/gsz || exit 0
echo "### updateHousehold callers (is whatsapp the customer contact or household data?) ###"
grep -rn "updateHousehold(" routes lib 2>/dev/null | grep -v node_modules | grep -iv "\.bak"
echo "--- context around each caller ---"
for L in $(grep -rn "updateHousehold(" routes/checkout.js 2>/dev/null | cut -d: -f2); do [ -n "$L" ] && sed -n "$((L-4)),$((L+2))p" routes/checkout.js; echo "   ·····"; done
echo
echo "### verifyClaim payload (587-598): is userPhone used for matching? ###"
sed -n '587,598p' routes/checkout.js
echo
echo "### activatePlayer payload (405-416) ###"
sed -n '405,416p' routes/checkout.js
echo
echo "### submitOrder payloads: the two userPhone lines in context (430-437 & 490-498) ###"
sed -n '430,437p' routes/checkout.js
echo "   ·····"
sed -n '490,498p' routes/checkout.js
echo
echo "### zayron orderDispatch.submit (54-62) ###"
sed -n '54,62p' /opt/zayron/lib/orderDispatch.js
echo DONE
