#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### product.ejs reviews panel (305-345) ###"
sed -n '305,345p' views/admin/../product.ejs 2>/dev/null || sed -n '305,345p' views/product.ejs
echo
echo "### products.js: canReview / alreadyReviewed / reviewMsg logic ###"
grep -nE "canReview|alreadyReviewed|reviewMsg|_cust|verified|customer" routes/products.js | grep -viE '\.bak' | head -30
echo
echo "### review submit route ###"
grep -rnE "/review|reviews\(|INSERT INTO reviews|canReview" routes/reviewpublic.js routes/products.js 2>/dev/null | grep -viE '\.bak' | head -20
