#!/usr/bin/env bash
# diagRenewStatus — galaxyzayron pollOnce renew handling + what renewStatus returns (new expiry / credentials /
# fields), so zayron finalizes a renewed line correctly. READ-ONLY.
set +e
cd /opt/gsz || exit 0
echo "### pollOnce (534-610): how it polls renewStatus and finalizes a renewal ###"
sed -n '534,610p' routes/checkout.js
echo DONE
