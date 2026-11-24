#!/usr/bin/env bash
# diagGszDeliver4 — read lib/deliver.js (markDelivered + WhatsApp send) and the checkout poll-finalize
# block, and confirm whether any timer already recovers stuck 'delivering' orders. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ lib/deliver.js (full) ############"
nl -ba lib/deliver.js
echo
echo "############ checkout.js poll-finalize block (500-575) + enclosing route ############"
sed -n '495,575p' routes/checkout.js
echo
echo "############ who calls markDelivered / polls statuses / any delivery timer? ############"
grep -rn "markDelivered\|renewStatus\|orderStatus(\|activateStatus\|setInterval\|CRON\|cron\|every.*min\|'delivering'\|\"delivering\"" --include=*.js . 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head -50
echo DONE
