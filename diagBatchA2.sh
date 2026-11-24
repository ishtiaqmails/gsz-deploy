#!/usr/bin/env bash
# READ-ONLY. The checkout front-end script: method render, pay-detail, the ask/name field, and the submit (file upload?).
Z=/opt/zayron; cd "$Z"
echo "### multer / upload setup + route defs ###"
grep -nE "multer|upload|req.file|\.single\(|router\.(get|post)\(|upDir" routes/checkout.js | head -20
echo
echo "### checkout front-end script (100-280) ###"
sed -n '100,280p' routes/checkout.js
echo DONE
