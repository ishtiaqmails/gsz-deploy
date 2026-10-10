#!/usr/bin/env bash
# dumpPay — payMethods() + pay-account shape, to build the in-modal popup checkout for Renew.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "## payMethods function ##"
L=$(grep -n "function payMethods" routes/checkout.js | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "${L},$((L+55))p" routes/checkout.js
echo
echo "## method fields + pay-account mapping + REGIONS ##"
grep -nE "methods\.push|botAcct|getPayAccounts|a\.title|a\.account|a\.iban|a\.instructions|\.pay\b|REGIONS *=|const REGIONS|cur:|rate:" routes/checkout.js 2>/dev/null | head -30
echo
echo "## /order page pay-account mapping (how details are shown) ##"
grep -nE "getPayAccounts|details:|Title:|Account:|instructions|payment_methods" routes/checkout.js 2>/dev/null | head -15
echo "== dumpPay done =="
