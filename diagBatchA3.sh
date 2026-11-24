#!/usr/bin/env bash
# READ-ONLY. The rest of the checkout front-end: method render JS, pay detail, the "ask" (name) block, zkPaid submit.
Z=/opt/zayron; cd "$Z"
echo "### checkout front-end script tail (210-410) ###"
sed -n '210,410p' routes/checkout.js
echo
echo "### gszApi.methodKey (for Wise->meezan mapping) ###"
grep -nE "function methodKey|methodKey" lib/gszApi.js | head
echo DONE
