#!/usr/bin/env bash
# diagRenewBug — the website renewal path on BOTH sites: does the renew call pass the content type (adult/family),
# and does it make the RESELLER BOT message the customer? READ-ONLY. Urgent production bug.
set +e
for APP in /opt/gsz /opt/zayron; do
  echo "################################# $APP #################################"
  cd "$APP" 2>/dev/null || { echo "(missing)"; continue; }
  echo "### renew endpoints + bridge renew payload (type/adult/content_type/notify/phone) ###"
  grep -rn "renew" routes lib 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | grep -iE "renew.*type|renew.*adult|content_type|submitRenew|renew\(|/api/.*renew|renew.*notify|renew.*phone|function renew|renew_line|renewLine" | head -25
  echo "--- the bridge renew fn (botapi/gszApi) ---"
  grep -rn "renew\|submit-renew\|renewStatus\|notify\|content_type\|type:" lib/botapi.js lib/gszApi.js 2>/dev/null | grep -iE "renew|notify|content|type:" | head -20
done
echo
echo "########## who sends the customer a 'renew' message (website vs bot) ##########"
grep -rni "renewed\|renewal.*success\|has been renewed\|subscription.*renewed" /opt/gsz/routes /opt/gsz/lib /opt/zayron/routes /opt/zayron/lib 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | head -20
echo DONE
