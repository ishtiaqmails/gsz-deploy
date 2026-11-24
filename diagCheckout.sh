#!/usr/bin/env bash
# diagCheckout — how the Buy button triggers checkout, how the checkout page is wrapped (for an embed mode),
# and the existing trial-modal pattern to mirror. Read-only.
set -e
cd /opt/zayron
echo "### Buy button markup on the server page (server.js) ###"
grep -n "buyBtn\|Buy now\|/checkout?s=\|data-ztrial\|freeTrialBtn\|zkbuy\|data-zbuy" server.js | head -20 || true
echo
echo "### checkout GET render wrapper (shellPage / layout / headers) ###"
grep -n "shellPage\|res.send\|router.get('/checkout\|function.*checkout\|embed\|noindex\|<header\|site-header" routes/checkout.js | head -30 || true
echo
echo "### checkout.js top: requires + how the page shell is built ###"
sed -n '1,20p' routes/checkout.js
echo
echo "### trial modal trigger in public/ztrial.js (pattern to mirror) ###"
[ -f public/ztrial.js ] && grep -n "addEventListener\|createElement\|modal\|overlay\|popup\|href\|fetch\|open(" public/ztrial.js | head -30 || echo "(no public/ztrial.js)"
echo
echo "### is there a global script include on the server page? ###"
grep -n "ztrial.js\|<script" server.js | head -15 || true
echo DONE
