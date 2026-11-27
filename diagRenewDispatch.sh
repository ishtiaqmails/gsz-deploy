#!/usr/bin/env bash
# diagRenewDispatch — zayron's dispatchOrder flow (resolve+submit), the account Renew button, the checkout server
# INSERT + query handling, renew_username usage, and galaxyzayron's renew/renewStatus shape. For true renewal. READ-ONLY.
set +e
cd /opt/zayron || exit 0
echo "### orderWorker.dispatchOrder (full: 40-92) ###"
sed -n '40,92p' lib/orderWorker.js
echo
echo "### account.js Renew button (520-535) ###"
sed -n '520,535p' routes/account.js
echo
echo "### checkout.js server-path INSERT + query handling (215-232) ###"
sed -n '215,232p' routes/checkout.js
echo
echo "### renew_username usage anywhere in zayron ###"
grep -rn "renew_username\|renew_of\|renew_line\|isRenew\|is_renew" routes lib 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | head
echo
echo "### galaxyzayron renew + renewStatus (bridge shape to mirror) ###"
grep -n "function renew\|renewStatus\|/api/renew" /opt/gsz/lib/botapi.js
echo "--- galaxyzayron renew fulfilment + poll (pollOnce renew handling) ---"
grep -n "renewStatus\|renew_line\|renewStatus(\|bot_order_id\|pollOnce" /opt/gsz/routes/checkout.js | head -15
echo DONE
