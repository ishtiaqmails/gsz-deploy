#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### account.js pay-methods handler (455-515) ###"
sed -n '455,515p' routes/account.js
echo
echo "### how account.js reads payment_logos / builds logo ###"
grep -nE "payment_logos|logo|SELECT .*FROM payment" routes/account.js | head -20
