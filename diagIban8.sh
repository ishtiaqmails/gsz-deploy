#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### every pay-methods handler (live files) ###"
grep -rnE "tools/pay-methods" routes/ lib/ server.js 2>/dev/null | grep -viE '\.bak|\.xbak'
echo
echo "### handlers that emit a logo field in a methods json (the live shape) ###"
grep -rnE "logo:" routes/ lib/ 2>/dev/null | grep -viE '\.bak|\.xbak' | grep -iE "m\.logo|name:m\.name|method" | head -20
echo
echo "### router mount order in server.js (account/checkout/tools) ###"
grep -nE "app\.use\(|require\(.?\./routes" server.js 2>/dev/null | grep -iE "account|checkout|tools|pay|router" | head -30
