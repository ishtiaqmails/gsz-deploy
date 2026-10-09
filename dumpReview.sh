#!/usr/bin/env bash
# dumpReview — full source of the paid/renew path for code review. Output goes to a file you upload.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "################# routes/checkout.js #################"
cat -n routes/checkout.js
echo
echo "################# lib/botapi.js #################"
cat -n lib/botapi.js
echo "== dumpReview done =="
