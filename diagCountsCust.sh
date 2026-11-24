#!/usr/bin/env bash
# READ-ONLY. Does /admin/customers exist? And how do counts flow from channels import to cards?
Z=/opt/zayron; cd "$Z"
echo "### /admin/customers route? ###"
grep -nE "router\.(get|post)\('/customers|'/customer" routes/admin.js || echo "(no customers route — page not built)"
echo
echo "### lib/channels exports + count functions ###"
grep -nE "module.exports|function |counts|channels|movies|series" lib/channels.js 2>/dev/null | head -20
echo
echo "### how {channels} tokens resolve on the website (server.js / data.js) ###"
grep -rnE "\{channels\}|\{movies\}|\{series\}|channels_auto|chanCount|liveCount|countFor|resolveTokens|channel_count" server.js lib/data.js routes/*.js 2>/dev/null | grep -viE "\.bak|admin.js" | head -15
echo
echo "### does the bot/bridge expose channel counts? (gsz-api products) ###"
grep -nE "channel|movies|series|count|library|vod" /home/claude/gsz-api/server.js 2>/dev/null | head -10 || echo "(gsz-api not local here)"
echo DONE
