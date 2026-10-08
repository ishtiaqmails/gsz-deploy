#!/usr/bin/env bash
# dumpBatch2 — Payments, Netflix, Issues, Messages views + render locals.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
for v in payments netflix issues messages; do
  echo "########## views/admin/$v.ejs ##########"; cat "views/admin/$v.ejs"; echo
done
echo "########## render signatures ##########"
for r in adminPayments adminNetflix adminIssues adminMessages; do
  echo "--- routes/$r.js (routes + render) ---"
  grep -nE "router\.(get|post)\(|res\.render" "routes/$r.js" 2>/dev/null
done
echo "== dumpBatch2 done =="
