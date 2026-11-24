#!/usr/bin/env bash
# READ-ONLY. Every getProducts() consumer + the two toggle files, so we fix the contract everywhere.
Z=/opt/zayron; cd "$Z"
echo "### all getProducts usages ###"
grep -rnE "getProducts" lib/ routes/ server.js 2>/dev/null | grep -viE "\.bak" | head -40
echo
echo "### lib/trialToggle.js (full) ###"
cat -n lib/trialToggle.js
echo
echo "### lib/paidToggle.js (full) ###"
cat -n lib/paidToggle.js
echo
echo "### admin.js — Bot product dropdown (_botProducts) ###"
grep -n "_botProducts\|getProducts\|bot_sku\|Bot product" routes/admin.js | head
echo DONE
