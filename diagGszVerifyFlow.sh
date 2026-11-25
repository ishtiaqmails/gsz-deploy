#!/usr/bin/env bash
# diagGszVerifyFlow — the REAL verification flow end to end: the /api/whatsapp/verification/* API + the bot
# webhook that links/verifies, AND the client "Galaxy Hub" modal that drives it. READ-ONLY. For the full rewrite.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ routes/whatsapp.js — verification API + webhook (200-380) ############"
grep -n "verification/start\|verification/:id/status\|verification/verify\|/internal/whatsapp/incoming\|wa_verified\|verificationEnabled\|wa_verification_enabled\|function.*verif\|audit\|VERIFICATION_STARTED\|VERIFICATION_COMPLETED\|VERIFY_NUMBER_MSG" routes/whatsapp.js
echo "--- start + status endpoints (205-266) ---"
sed -n '205,266p' routes/whatsapp.js
echo
echo "############ the client modal: find the file(s) ############"
grep -rln "Send this code to us\|Waiting for your message\|verification/start\|Open WhatsApp & send\|Verify your WhatsApp\|Galaxy Hub" --include=*.js --include=*.ejs public views 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head
echo
echo "############ modal JS: verify UI + poll logic ############"
MF=$(grep -rln "verification/start\|Waiting for your message\|Send this code to us" --include=*.js --include=*.ejs public views 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head -1)
echo "modal file: $MF"
[ -n "$MF" ] && grep -n "verification/start\|verification/\|/status\|Send this code\|Waiting for\|Verify your WhatsApp\|code\|poll\|fetch(\|wa_verified\|signed in\|not signed" "$MF" | head -40
echo DONE
