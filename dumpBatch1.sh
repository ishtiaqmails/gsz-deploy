#!/usr/bin/env bash
# dumpBatch1 — Categories, Reviews, Labels views + Coupons/Labels render locals.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## categories.ejs ##########"; cat views/admin/categories.ejs
echo; echo "########## reviews.ejs ##########"; cat views/admin/reviews.ejs
echo; echo "########## labels.ejs ##########"; cat views/admin/labels.ejs
echo; echo "########## adminCoupons.js — GET /coupons handler + render ##########"
grep -nE "router\.(get|post)\(|res\.render" routes/adminCoupons.js
echo "--- coupons GET handler ---"; sed -n "/router.get('\/coupons'/,/});/p" routes/adminCoupons.js | head -40
echo; echo "########## adminLabels.js — routes + render ##########"
grep -nE "router\.(get|post)\(|res\.render" routes/adminLabels.js
echo "--- labels GET handler ---"; sed -n "/router.get('\/labels'/,/});/p" routes/adminLabels.js | head -40
echo "== dumpBatch1 done =="
