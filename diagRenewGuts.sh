#!/usr/bin/env bash
# diagRenewGuts — exact galaxyzayron renew payload (phone/type passed to the bot?) + where the Adult/Family choice is
# captured into renew_line. READ-ONLY.
set +e
cd /opt/gsz || exit 0
echo "### checkout.js 345-395 (the two botapi.renew calls + payload) ###"
sed -n '345,395p' routes/checkout.js
echo
echo "### checkout.js 815-885 (renew_line build + content_type/version) ###"
sed -n '815,885p' routes/checkout.js
echo
echo "### where the renew Adult/Family choice is set on the renew UI/flow (version/content_type/ct) ###"
grep -rn "renew_line\|\.version\|content_type\|ct=\|'adult'\|\"adult\"\|renewLine\|renew.*adult\|adult.*renew" routes/checkout.js 2>/dev/null | grep -iE "version|adult|content_type|renew_line|ct" | head -25
echo
echo "### does the reseller-bot /api/renew payload carry a customer phone/notify? (botapi.renew callers) ###"
grep -n "botapi.renew(" routes/checkout.js
echo DONE
