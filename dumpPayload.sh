#!/usr/bin/env bash
# dumpPayload — the two submitOrder payload objects (to add productName precisely).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## single bot-order submit payload (~330-365) ##########"
sed -n '330,365p' routes/checkout.js
echo
echo "########## cart item submit payload (~378-408) ##########"
sed -n '378,408p' routes/checkout.js
echo "== dumpPayload done =="
