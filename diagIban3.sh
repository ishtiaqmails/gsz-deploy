#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### grep anchors ###"
grep -nE "pm-details|pm-extra|extra_value|forEach\(function\(m" views/checkout.ejs
echo "### block 188-215 ###"
sed -n '188,215p' views/checkout.ejs
echo "### pm-details / pm-extra CSS ###"
grep -nE "\.pm-details|\.pm-extra" views/checkout.ejs
echo "### checkout.js returns + helper ###"
grep -nE "_attachExtras|return \{ methods" routes/checkout.js
