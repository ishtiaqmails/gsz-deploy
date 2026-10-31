#!/usr/bin/env bash
# stepBotPrice.sh — add owner `price <product> [plan] [country]` command to the website's
#   ownerCommand() (routes/whatsapp.js). The verification bot already relays owner messages here,
#   so no bot changes are needed. Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
F=routes/whatsapp.js
cp -f "$GSZ/$F" "$GSZ/$F.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/$F.bak.$TS" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch"
node "$SRC/patch_botprice.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/$F" && echo "  whatsapp.js ok"
node --check "$GSZ/lib/gsz_pricing.js" && echo "  gsz_pricing.js ok (engine reachable)"
grep -q "t.toLowerCase().indexOf('price ')" "$GSZ/$F" && echo "  price command present"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo
echo "DONE — from your OWNER WhatsApp number, message the verification bot:"
echo "   price netflix            (US/\$ default, all plans)"
echo "   price netflix 1month GB  (one plan, as seen in Britain)"
echo "   price \"spotify\" family AE"
echo "Send 'help' to the bot to see it listed. (Owner numbers = wa_settings.wa_owner_numbers.)"
