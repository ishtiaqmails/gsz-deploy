#!/usr/bin/env bash
# diagGszVerifyGuts — exact source of the client wv() modal + its helpers, and whatsapp.js waStatus()/genCode/
# webhook link code, so the full site-OTP rewrite is precise. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ hub_model.ejs — the wv() WhatsApp-verify block (full) ############"
L=$(grep -n "verification/start" views/partials/hub_model.ejs | head -1 | cut -d: -f1)
echo "wv start at line ~$L"
[ -n "$L" ] && sed -n "$((L>8?L-8:1)),$((L+55))p" views/partials/hub_model.ejs
echo
echo "############ wv helpers: wvStop / wvRetryBox / wvSuccess + the Verify-now button wiring ############"
grep -n "function wv\|wvStop\|wvRetryBox\|wvSuccess\|wv-go\|VERIFIED\|function esc\|function authErr\|verifyWa\|startWv\|function wv(" views/partials/hub_model.ejs | head -30
echo
echo "############ whatsapp.js: waStatus(), genCode(), reqIp(), and the webhook identity-link/verify (330-375) ############"
grep -n "function waStatus\|function genCode\|function reqIp\|async function settings\|require('../lib/wanotify')\|wanotify" routes/whatsapp.js | head
sed -n '185,200p' routes/whatsapp.js
echo "--- webhook link/verify 330-375 ---"
sed -n '330,375p' routes/whatsapp.js
echo DONE
