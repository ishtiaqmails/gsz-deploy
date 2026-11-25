#!/usr/bin/env bash
# diagWabotPanel — the LIVE wabot panel: wabot.js render(toggles) + POST /toggles handler, and the live view's
# VERIFICATION form, to add a 'Send code from website' toggle wired to wa_verify_mode. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ wabot.js: render + toggles object + POST /toggles ############"
grep -n "res.render\|toggles\s*:\|toggles\s*=\|setWa\|/toggles\|verificationEnabled\|requireCheckout\|requireTrial\|orderNotifications\|wa_verify_mode\|function on" routes/wabot.js
echo "--- wabot.js 55-140 ---"
sed -n '55,140p' routes/wabot.js
echo
echo "############ live view path + VERIFICATION form ############"
VN=$(grep -oE "res\.render\(['\"][^'\"]+" routes/wabot.js | head -1 | sed -E "s/res\.render\(['\"]//")
echo "render view name: $VN"
for cand in "views/$VN.ejs" "views/admin/$VN.ejs" "views/${VN}"; do
  [ -f "$cand" ] && { echo "=== LIVE VIEW: $cand ==="; L=$(grep -n "WhatsApp verification\|VERIFICATION" "$cand" | head -1 | cut -d: -f1); [ -n "$L" ] && sed -n "$((L>4?L-4:1)),$((L+22))p" "$cand"; break; }
done
echo DONE
