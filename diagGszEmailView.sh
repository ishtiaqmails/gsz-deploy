#!/usr/bin/env bash
# diagGszEmailView — the existing email-verify view + its route handler + the render shell, to model the new
# WhatsApp verify page on. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ views/account/ files ############"
ls -la views/account/ 2>/dev/null | head
echo
echo "############ verify_email view (to mirror) ############"
sed -n '1,120p' views/account/verify_email.ejs 2>/dev/null
echo
echo "############ account.js: shell() + email-verify GET/POST handlers ############"
grep -n "async function shell\|function shell\|res.render\|verify-email\|verify_email\|requireLogin" routes/account.js | head -30
echo "--- email-verify GET+POST bodies (185-225) ---"
sed -n '185,230p' routes/account.js
echo DONE
