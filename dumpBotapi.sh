#!/usr/bin/env bash
# dumpBotapi — the website<->bot bridge + trial delivery/poller + DNS/player handling.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## lib/botapi.js (full) ##########"; cat lib/botapi.js 2>&1
echo; echo "########## where trial credentials are delivered / polled (grep) ##########"
grep -rnE "trial-status|trialStatus|generateTrial|UPDATE trial_claims|trial_claims SET|deliverTrial|trialPoller|poll" routes/ lib/ server.js 2>/dev/null | grep -v node_modules | head -60
echo; echo "########## any trial poller file(s) ##########"
grep -rln "trial" lib/ routes/ 2>/dev/null | grep -v node_modules
echo "--- setInterval / cron in server.js ---"; grep -nE "setInterval|trial|poll|cron" server.js | head
echo; echo "########## /api/trial-status route (find + show) ##########"
grep -rn "trial-status" routes/ lib/ server.js 2>/dev/null
echo; echo "########## bot api config in .env (names + masked values) ##########"
grep -iE "BOT|TRIAL|WABOT|WA_" .env 2>/dev/null | sed -E 's/(KEY|TOKEN|SECRET|PASS)=.*/\1=***/I'
echo "== dumpBotapi done =="
