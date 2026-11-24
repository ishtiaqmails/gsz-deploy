#!/usr/bin/env bash
# READ-ONLY. data.js server-object + counts/token/chCounts code, and where cards render ch/vod/series.
Z=/opt/zayron; cd "$Z"
echo "### data.js 1-60 (server object) ###"; sed -n '1,60p' lib/data.js
echo; echo "### data.js 120-280 (counts/tokens/chCounts/chanCount) ###"; sed -n '120,280p' lib/data.js
echo; echo "### data.js 305-327 (getPublicData + exports) ###"; sed -n '305,327p' lib/data.js
echo; echo "### where cards render ch/vod/series counts ###"
grep -rnE "\.ch\b|Live channels|Movies|\.vod\b|\.series\b|chanCount|seriesCount|movieCount" public/js/cards.js server.js 2>/dev/null | grep -viE "\.bak" | head -20
echo DONE
