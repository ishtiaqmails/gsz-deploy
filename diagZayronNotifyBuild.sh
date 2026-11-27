#!/usr/bin/env bash
# diagZayronNotifyBuild — the half-built notifyOwner, the order-INSERT + status-transition hook points, and gszApi.req
# so I can add a notify method + owner-alert builder routed to the reseller bot /api/notify. READ-ONLY.
set +e
cd /opt/zayron || exit 0
echo "### lib/_notifyOwner_new.js (full) ###"
sed -n '1,120p' lib/_notifyOwner_new.js
echo
echo "### checkout.js: order INSERT (both paths) + where it becomes verified/review/rejected ###"
sed -n '200,235p' routes/checkout.js
echo "   ·····verify region·····"
sed -n '495,512p' routes/checkout.js
echo
echo "### orderWorker: verify + deliver hook points (82-90, 150-165, 225-235) ###"
sed -n '82,90p' lib/orderWorker.js
echo "   ·····"
sed -n '150,165p' lib/orderWorker.js
echo "   ·····"
sed -n '225,235p' lib/orderWorker.js
echo
echo "### gszApi.req signature + exports (to add notify) ###"
sed -n '24,45p' lib/gszApi.js; grep -n "module.exports" lib/gszApi.js
echo DONE
