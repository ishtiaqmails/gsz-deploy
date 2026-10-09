#!/usr/bin/env bash
# dumpAcct2 — account route + views internals for the dashboard rebuild. Output to a file you upload.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "################# routes/account.js #################"
cat -n routes/account.js
echo
echo "################# views/account (listing) #################"
ls -la views/account/ 2>/dev/null
echo
for f in views/account/*.ejs; do
  [ -f "$f" ] || continue
  echo "################# $f #################"
  cat -n "$f"
  echo
done
echo "################# view engine / layout / account mount #################"
grep -rnE "view engine|express-ejs-layouts|app\.set\(|app\.use\([^)]*account|require\('\./routes/account|routes/account" server.js app.js index.js main.js 2>/dev/null | head -30
echo "== dumpAcct2 done =="
