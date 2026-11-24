#!/usr/bin/env bash
# READ-ONLY. Exact bytes of the admin nav line for Card numbers (to remove it precisely).
cd /opt/zayron
grep -n "Card numbers\|channels/counts\|channels/paste" routes/admin.js | head
echo "--- cat -A of those lines ---"
grep -nA0 "channels/paste\|channels/counts" routes/admin.js | cat -A | head
echo DONE
