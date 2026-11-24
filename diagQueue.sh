#!/usr/bin/env bash
# diagQueue — confirm trial/order provisioning is serialized (queue-respecting, no panel hammer), and grab
# the exact checkout ctAvail + content-toggle block to switch it to the cached bot `types`. Read-only.
set -e
cd /opt/zayron
echo "############ lib/botQueue.js (trial queue) ############"
[ -f lib/botQueue.js ] && nl -ba lib/botQueue.js || echo "(no lib/botQueue.js)"
echo
echo "############ lib/orderDispatch.js (submit/poll/resolvePackage) ############"
nl -ba lib/orderDispatch.js
echo
echo "############ orderWorker runDispatch (how many orders per tick) ############"
sed -n '95,170p' lib/orderWorker.js
echo
echo "############ checkout.js 256-312 (ctAvail + content toggle to edit) ############"
sed -n '256,312p' routes/checkout.js
echo DONE
