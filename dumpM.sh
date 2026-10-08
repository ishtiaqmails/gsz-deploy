#!/usr/bin/env bash
# dumpM — mailer.js (attachment param) + emailOrder() + PDF-lib availability.
GSZ=/opt/gsz; cd "$GSZ"
echo "########## lib/mailer.js ($(wc -l < lib/mailer.js) lines) ##########"
cat -n lib/mailer.js
echo
echo "########## emailOrder() in routes/checkout.js (lines 40-120) ##########"
sed -n '40,120p' routes/checkout.js | cat -n
echo
echo "########## node + PDF libs ##########"
node -v
echo "pdfkit:    $( [ -d node_modules/pdfkit ] && echo present || echo MISSING )"
echo "pdf-lib:   $( [ -d node_modules/pdf-lib ] && echo present || echo MISSING )"
echo "puppeteer: $( [ -d node_modules/puppeteer ] && echo present || echo MISSING )"
echo "--- npm install pdfkit (dry, test reachability) ---"
npm view pdfkit version 2>&1 | head -2
