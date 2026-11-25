#!/usr/bin/env bash
# diagWabot — how the Verification Bot (/opt/gsz-wabot/bot.js) composes/sends messages, what is branded
# galaxyzayron-only, its verify flow, and whether it already knows a message/order 'source'. READ-ONLY.
set +e
D=/opt/gsz-wabot
[ -d "$D" ] || { echo "no $D"; exit 0; }
echo "############ files + size ############"
ls -la "$D" | grep -vE "node_modules|\.git" | head -40
echo "bot.js lines: $(wc -l < "$D/bot.js" 2>/dev/null)"
echo
echo "############ branding / website references (zayron vs galaxyzayron) ############"
grep -rniE "zayron|galaxyzayron|galaxy subz|galaxytools|site_?name|website|brand" "$D"/*.js 2>/dev/null | grep -v node_modules | head -40
echo
echo "############ /send endpoint + how a message/text arrives ############"
grep -nE "/send|app\.(get|post)|router\.(get|post)|sendMessage|sendText|function send|module.exports" "$D/bot.js" 2>/dev/null | head -40
echo
echo "############ verification flow (reverse: customer -> bot) + code handling ############"
grep -niE "verif|otp|code|verify-claim|confirm.*code|enter.*code|link.*whatsapp|identity" "$D/bot.js" 2>/dev/null | head -40
echo
echo "############ does it see a 'source' / per-site anything? ############"
grep -niE "source|origin|from_site|site=|tenant|zayron-web|gsz_website|zayron\.tv|galaxyzayron\.store" "$D"/*.js 2>/dev/null | grep -v node_modules | head -30
echo DONE
