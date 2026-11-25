#!/usr/bin/env bash
# diagGszVerifyDead — exact source of the now-dead WhatsApp verify routes/helpers to remove cleanly, and a full-repo
# check that nothing else references them. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "### account.js 223-266 (helpers + legacy routes to remove) ###"
sed -n '223,266p' routes/account.js
echo
echo "### full-repo references to the dead symbols (should only be account.js defs + the ejs itself) ###"
grep -rn "verify-whatsapp\|verify_whatsapp\|sendWaCode\|waVerifyMode" --include=*.js --include=*.ejs routes views lib 2>/dev/null | grep -v node_modules | grep -v "/\.retired/"
echo
echo "### the view file ###"
ls -l views/account/verify_whatsapp.ejs 2>/dev/null || echo "(no verify_whatsapp.ejs)"
echo DONE
