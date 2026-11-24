#!/usr/bin/env bash
# diagBot — how the gsz-api bridge caches reads and how trials/paid orders are submitted + polled, so we
# can cut any bot hammering and keep everything on the bot's queue. Read-only.
set -e
cd /opt/zayron
echo "############ lib/gszApi.js (full bridge client) ############"
nl -ba lib/gszApi.js
echo
echo "############ getProducts cache? (grep) ############"
grep -n "cache\|TTL\|setTimeout\|setInterval\|getProducts\|_prodCache\|Date.now" lib/gszApi.js | head -40 || true
echo
echo "############ poll cadence: trial + order status loops ############"
grep -rn "setInterval\|setTimeout\|poll\|sleep\|retry\|every\|meta http-equiv=\"refresh\"\|refresh" routes/trial.js lib/orderWorker.js lib/orderDispatch.js routes/checkout.js 2>/dev/null | grep -v node_modules | head -40 || true
echo DONE
