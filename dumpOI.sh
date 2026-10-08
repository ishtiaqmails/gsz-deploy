#!/usr/bin/env bash
# dumpOI — order page + invoice page + the order-email builder (for dark re-theme + premium email).
GSZ=/opt/gsz; cd "$GSZ"
for f in views/order.ejs views/invoice.ejs lib/emails.js; do
  echo "########## $f ($( [ -f "$f" ] && wc -l < "$f" || echo MISSING ) lines) ##########"
  [ -f "$f" ] && cat -n "$f"
  echo
done
echo "########## route that renders 'invoice' ##########"
grep -rn "render('invoice'" routes/*.js 2>/dev/null
echo
echo "########## emailOrder definition + where it lives ##########"
grep -rn "function emailOrder\|emailOrder =" lib/*.js routes/*.js 2>/dev/null
echo
echo "########## how order.ejs is rendered (vars it gets) ##########"
grep -rn "render('order'" routes/*.js 2>/dev/null
