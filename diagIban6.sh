#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### /account/tools/pay-methods handler ###"
grep -nA 30 "tools/pay-methods" routes/checkout.js | head -40
