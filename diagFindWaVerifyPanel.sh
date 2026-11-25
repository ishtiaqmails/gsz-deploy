#!/usr/bin/env bash
# diagFindWaVerifyPanel — locate the "WhatsApp verification" toggles panel (the one in the screenshot) and its
# save handler, so the new verification-method toggle goes there. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ files containing the panel's text ############"
grep -rln "Verification system enabled\|Require WhatsApp at checkout\|Require WhatsApp for free trials\|WhatsApp verification\|Order notifications via WhatsApp\|Changes apply site-wide" --include=*.js --include=*.ejs . 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head
echo
echo "############ the view/section rendering those toggles ############"
F=$(grep -rln "Require WhatsApp at checkout\|Verification system enabled" --include=*.ejs . 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head -1)
echo "view file: $F"
[ -n "$F" ] && { L=$(grep -n "Verification system enabled\|WhatsApp verification" "$F" | head -1 | cut -d: -f1); sed -n "$((L>6?L-6:1)),$((L+60))p" "$F"; }
echo
echo "############ the route/save handler for these keys ############"
grep -rn "wa_verification_enabled\|wa_required_for_checkout\|wa_required_for_trials\|wa_order_notifications_enabled\|Save settings\|/verification\|verify-settings\|wa-verify-settings" --include=*.js routes 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head -25
echo DONE
