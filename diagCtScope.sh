#!/usr/bin/env bash
# diagCtScope — is gszApi in scope where the ctAvail block runs in checkout.js? Show the require + the block.
set -e
cd /opt/zayron
echo "### gszApi require in checkout.js (and its scope) ###"
grep -n "gszApi\|require('./gszApi')\|require(\"./gszApi\")\|require('../lib/gszApi')" routes/checkout.js || echo "NO gszApi reference found"
echo
echo "### the ctAvail block as currently deployed ###"
grep -n "ctAvail\|_bsku\|getProducts\|_bp\|_types" routes/checkout.js | head -20 || true
echo
echo "### context lines 238-250 ###"
sed -n '238,250p' routes/checkout.js
echo DONE
