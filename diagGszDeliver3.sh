#!/usr/bin/env bash
# diagGszDeliver3 — read the bot client, the admin manual-deliver handler, and the checkout deliver/notify
# path, so we can build an auto-recovery that reuses the SAME finalize logic. READ-ONLY (no bot writes).
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ lib/botapi.js (methods + timeouts) ############"
nl -ba lib/botapi.js
echo
echo "############ admin manual-deliver / resend handler (the button you click) ############"
grep -rn "redeliver\|re-deliver\|resend\|manual.*deliver\|force.*deliver\|deliver.*now\|/deliver\|markDelivered\|finishDelivery\|completeOrder" --include=*.js routes/ server.js 2>/dev/null | grep -v "/\.bak" | head -30
echo
echo "############ lib/deliveryMsg.js (how the WhatsApp message is built/sent) ############"
nl -ba lib/deliveryMsg.js | head -80
echo DONE
