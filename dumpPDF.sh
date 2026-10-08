#!/usr/bin/env bash
# dumpPDF — the existing PDF module (pdfdocs) + how it's required.
GSZ=/opt/gsz; cd "$GSZ"
echo "########## require of pdfdocs in routes/checkout.js ##########"
grep -n "pdfdocs" routes/checkout.js | head
echo
echo "########## locate the module file ##########"
ls -la lib/ | grep -i pdf
echo
F=$(grep -oE "require\('[^']*pdf[^']*'\)" routes/checkout.js | head -1 | sed -E "s/require\('(.*)'\)/\1/")
echo "resolved require: $F"
echo
for cand in lib/pdfdocs.js lib/pdf.js lib/pdfDocs.js; do
  if [ -f "$cand" ]; then
    echo "########## $cand ($(wc -l < "$cand") lines) ##########"
    cat -n "$cand"
    echo
  fi
done
