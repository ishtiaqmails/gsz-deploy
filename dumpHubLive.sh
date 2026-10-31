#!/usr/bin/env bash
# dumpHubLive.sh — the LIVE hub modal auth + the SPA loader, so I patch the real files safely.
set -uo pipefail
GSZ=/opt/gsz
HM="$GSZ/views/partials/hub_model.ejs"
SB="$GSZ/views/partials/store_bottom.ejs"
AN="$GSZ/views/partials/app_nav.ejs"

echo "========== HUB MODEL ($HM) =========="
echo "lines: $(wc -l < "$HM")"
echo "--- auth region (login + signup form builders + handlers) ---"
L=$(grep -n "Email or WhatsApp" "$HM" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "${L:-}" ]; then S=$((L>25?L-25:1)); E=$((L+75)); sed -n "${S},${E}p" "$HM"; else echo "(Email or WhatsApp not found in live hub_model.ejs)"; fi
echo
echo "--- auth footer (signed-out Sign In / Create Account buttons) ---"
grep -n -B1 -A2 "cthmSignIn\|cthmReg" "$HM" 2>/dev/null | head -24
echo
echo "--- window.__gszAuth definition ---"
grep -n -A8 "__gszAuth" "$HM" "$SB" "$AN" 2>/dev/null | head -30

echo
echo "========== STORE BOTTOM SPA loader ($SB) =========="
echo "lines: $(wc -l < "$SB")"
echo "--- load() function ---"
grep -n -A22 "function load" "$SB" 2>/dev/null | head -34
echo "--- /login /signup link interception ---"
grep -n "pathname===.'/login'\|pathname===.'/signup'\|'/login'\|'/signup'\|__gszAuth\|auth-open" "$SB" 2>/dev/null | head -20

echo
echo "========== APP NAV live auth buttons ($AN) =========="
grep -n "gnaSignIn\|gnaReg\|__gszAuth\|/login\|/signup" "$AN" 2>/dev/null | head -14
echo
echo "DONE"
