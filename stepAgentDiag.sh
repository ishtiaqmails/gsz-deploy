#!/usr/bin/env bash
# stepAgentDiag.sh — READ ONLY. Full served agent script + url endpoint + player_api helper (fetch.js), to add player_api fallback.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ" || { echo "no $GSZ"; exit 1; }

echo "===== 1) served AGENT script (full array) + agent.sh route ====="
L=$(grep -n "const AGENT" routes/iptv.js | head -1 | cut -d: -f1)
echo "AGENT at line ${L:-?}"
[ -n "${L:-}" ] && sed -n "${L},$((L+55))p" routes/iptv.js

echo; echo "===== 2) /internal/iptv/url/:sku endpoint (what the phone gets) ====="
U=$(grep -n "internal/iptv/url/:sku" routes/iptv.js | head -1 | cut -d: -f1)
[ -n "${U:-}" ] && sed -n "${U},$((U+14))p" routes/iptv.js

echo; echo "===== 3) fetch.js — player_api actions, url shape, output structure ====="
wc -l lib/iptv/fetch.js
grep -nE "player_api|action=|get_live|get_vod|get_series|categor|function |module.exports|return \{|fetchAll" lib/iptv/fetch.js | head -40

echo; echo "===== 4) fetch.js fetchAll body (how it assembles live/vod/series+cats) ====="
F=$(grep -n "fetchAll" lib/iptv/fetch.js | head -1 | cut -d: -f1)
[ -n "${F:-}" ] && sed -n "${F},$((F+45))p" lib/iptv/fetch.js
echo DONE
