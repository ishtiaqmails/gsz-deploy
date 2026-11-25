#!/usr/bin/env bash
# diagZayronDispatch — how zayron fulfils + delivers an order (how IPTV-specific it is; can the bot return generic
# credentials for other types), and the current delivery message format. Feeds req#1 (all products) + req#2 (msg). READ-ONLY.
set +e
cd /opt/zayron 2>/dev/null || { echo "no /opt/zayron"; exit 0; }
echo "########## lib/orderDispatch.js (FULL — the fulfilment path) ##########"
wc -l lib/orderDispatch.js 2>/dev/null; sed -n '1,120p' lib/orderDispatch.js 2>/dev/null
echo
echo "########## gszApi.submitOrder / orderStatus (what the bot returns on fulfil) ##########"
grep -n "submitOrder\|orderStatus\|function\|credentials\|line\|m3u\|username\|password\|url\|fields" lib/gszApi.js | head -30
echo
echo "########## how the delivered message is built + sent to the customer ##########"
grep -rn "deliver\|credentials\|Username\|Password\|order.*ready\|wa_send\|waSend\|otp_outbox\|sendTo\|message" lib/orderWorker.js lib/orderDispatch.js 2>/dev/null | grep -v node_modules | head -25
echo DONE
