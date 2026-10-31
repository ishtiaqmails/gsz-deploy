#!/usr/bin/env bash
# dumpHubCss.sh — the Hub modal's layout CSS + structure, so I can make every view fit
# with NO scroll (hide tabs chrome during auth, fit the viewport, compact spacing).
set -uo pipefail
HM=/opt/gsz/views/partials/hub_model.ejs
echo "========== <style> block (the .cthm layout CSS) =========="
awk 'BEGIN{p=0} /<style/{p=1} p{print NR": "$0} /<\/style>/{if(p){print "--- end style ---"; p=0}}' "$HM" | head -160
echo
echo "========== modal markup skeleton (structural elements) =========="
grep -nE "class=\"(cthm|cthm-[a-z]+)\b|id=\"cthm" "$HM" | grep -vE "addEventListener|querySelector|getElementById|innerHTML|createElement" | head -40
echo
echo "========== how the modal opens/sizes (open fn, scroll lock, body height) =========="
grep -n "cthm-body\|cthm-foot\|cthm-head\|cthm-tabs\|maxHeight\|max-height\|scrollLock\|classList.add('on')\|modal.classList" "$HM" | grep -iE "height|scroll|head|tabs|body|foot|open|on'" | head -24
echo
echo "DONE"
