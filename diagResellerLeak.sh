#!/usr/bin/env bash
# diagResellerLeak — every place a CUSTOMER phone is sent to the reseller bot (bridge) on BOTH sites, so the bot can
# never message/register a website customer. Owner alerts (botapi.notify) are separate & fine. READ-ONLY.
set +e
for APP in /opt/gsz /opt/zayron; do
  echo "################################# $APP #################################"
  cd "$APP" 2>/dev/null || { echo "(missing)"; continue; }
  BR=$( [ -f lib/botapi.js ] && echo botapi || echo gszApi )
  echo "bridge module: $BR"
  echo "--- bridge methods the site can call ---"
  grep -n "module.exports" lib/$BR.js 2>/dev/null | head -2
  echo "--- every call that passes a customer phone (whatsapp / userPhone / phone:) to the bridge ---"
  grep -rn "whatsapp:\|userPhone:\|phone:\|userWhatsapp\|customerPhone\|o\.whatsapp\|o\.phone" routes lib 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | grep -iE "whatsapp:|userphone:|phone:" | head -40
  echo "--- which of those are inside a bridge fulfilment call (submitOrder/renew/activate/generateTrial/updateHousehold/verifyClaim/iptvLookup) ---"
  grep -rn "submitOrder(\|\.renew(\|activatePlayer(\|generateTrial(\|updateHousehold(\|verifyClaim(\|iptvLookup(\|submit(" routes lib 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | head -30
done
echo DONE
