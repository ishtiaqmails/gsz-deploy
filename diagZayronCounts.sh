#!/usr/bin/env bash
# READ-ONLY. Where zayron renders counts (data.js server obj + {channels} tokens) + admin counts section to remove.
Z=/opt/zayron; cd "$Z"
echo "### data.js: server object mapping (channels/movies/series) ###"
grep -nE "channels|movies|series|getPublicData|reseller_pid|bot_sku|slug" lib/data.js | head -30
echo
echo "### how {channels}/{movies}/{series} tokens resolve ###"
grep -rnE "\{channels\}|\{movies\}|\{series\}|replace.*channels|tokens|fillTokens|renderTokens" server.js lib/*.js 2>/dev/null | grep -viE "\.bak|admin" | head -12
echo
echo "### server-page 'Browse everything included' count ###"
grep -nE "Browse everything|everything included|total.*chan|chan.*total" server.js | head
echo
echo "### admin counts section (nav + route) to remove ###"
grep -nE "channels/counts|Card numbers|/channels|TOKEN_HINT|Live TV channels|Movies / VOD" routes/admin.js | head -15
echo DONE
