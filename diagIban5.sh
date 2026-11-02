#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
F=views/partials/checkout_model.ejs
echo "### METHODS / data source in $F ###"
grep -nE "METHODS|typeOptions|fetch\(|/api/|JSON.stringify|var ms|methods" "$F" | head -40
echo
echo "### route/api that feeds this modal ###"
grep -rnE "checkout_model|typeOptions|getPayAccounts|quickbuy|gbuy|/buy|payMethods" routes/ server.js 2>/dev/null | grep -viE "\.bak|node_modules" | head -30
