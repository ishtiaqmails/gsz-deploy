#!/usr/bin/env bash
# diagGszSignupRoute — does signup / anything still route to the old step-1 server page (/account/verify-whatsapp)
# or its sendWaCode, now that the Hub modal is the live site-OTP flow? READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "### who references the old step-1 server page / its helper ###"
grep -rn "verify-whatsapp\|_waNext\|sendWaCode\|waVerifyMode\|verify_whatsapp" routes views 2>/dev/null | grep -v node_modules | head -40
echo
echo "### signup success redirect (account.js) ###"
grep -n "_waNext\|res.redirect\|signup\|register\|sendWaCode\|site_otp" routes/account.js 2>/dev/null | head -30
echo DONE
