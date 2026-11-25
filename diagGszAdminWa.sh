#!/usr/bin/env bash
# diagGszAdminWa — where admin manages wa_settings toggles (to add wa_verify_mode) + the account dashboard's
# WhatsApp verification section (to add the site_otp "Verify" button). READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ admin files that touch wa_settings ############"
grep -rln "wa_settings\|wa_verification_enabled\|wa_required_for_trials\|wa_verify_number\|wa_bot_send_url" --include=*.js routes 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head
echo
echo "############ admin WhatsApp settings panel + save handler ############"
grep -rn "wa_verification_enabled\|wa_required_for_trials\|wa_required_for_checkout\|require_wa_verify\|wa_settings\|saveWaSetting\|UPDATE wa_settings\|INSERT INTO wa_settings\|/admin.*whatsapp\|wa-settings\|waSettings" --include=*.js routes/adminWhatsapp.js routes/admin.js routes/admin2.js 2>/dev/null | grep -v "/\.bak" | head -30
echo
echo "############ account dashboard: WhatsApp verification section ############"
grep -rn "wa.verified\|wa_verified\|Verify.*WhatsApp\|verify-whatsapp\|message.*bot\|wa_verify_number\|verify your whatsapp\|wa.phone" views/account/dashboard.ejs 2>/dev/null | head -25
echo "--- account route: what wa / mode it passes to the dashboard (account.js 224-253) ---"
sed -n '224,253p' routes/account.js
echo DONE
