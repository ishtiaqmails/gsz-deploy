#!/usr/bin/env bash
# diagSubmitPayload — how the submitOrder payload sets content type (bot_type) + whether it passes whatsapp, so the
# renew-fallback can carry Adult and we can safely stop the bot messaging. READ-ONLY.
set +e
cd /opt/gsz || exit 0
echo "### payload construction around the submit (400-460) ###"
sed -n '400,460p' routes/checkout.js
echo
echo "### everywhere 'type' / bot_type feeds the bot payload ###"
grep -n "type:\|bot_type\|payload\s*=\|payload\." routes/checkout.js | sed -n '1,30p'
echo DONE
