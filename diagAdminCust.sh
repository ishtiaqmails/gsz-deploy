#!/usr/bin/env bash
# READ-ONLY. Admin customers management (to add admin change-number + force re-verify) and where card/page counts come from.
Z=/opt/zayron; cd "$Z"
echo "### admin routes mentioning customers ###"
grep -nE "customers|/customer|phone_verified|verify" routes/admin.js | head -30
echo
echo "### where server counts (live/movies/series) are stored/rendered ###"
grep -rnE "live_channels|movies|series|channel_count|counts|num_channels|vod|chan" routes/admin.js lib/data.js server.js 2>/dev/null | grep -viE "\.bak" | head -25
echo DONE
