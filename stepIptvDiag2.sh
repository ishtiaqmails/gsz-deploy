#!/usr/bin/env bash
# stepIptvDiag2.sh — READ ONLY. Full m3u.js parser + clean.js enhance (to fix the OOM memory handling).
set -uo pipefail
GSZ=/opt/gsz

echo "===== lib/iptv/m3u.js (FULL — the parser that OOMs) ====="
wc -l "$GSZ/lib/iptv/m3u.js" 2>/dev/null
echo "--------------------------------------------------------"
cat -n "$GSZ/lib/iptv/m3u.js" 2>/dev/null

echo; echo "===== lib/iptv/clean.js (structure) ====="
wc -l "$GSZ/lib/iptv/clean.js" 2>/dev/null
grep -nE "function |module.exports|exports\.|enhance|dedup|new Map|new Set|\.push|\.sort|\.slice|\.map|countries|categories|quality|variants|episodes" "$GSZ/lib/iptv/clean.js" 2>/dev/null | head -50
echo DONE-IPTVDIAG2
