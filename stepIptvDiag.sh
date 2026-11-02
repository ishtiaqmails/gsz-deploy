#!/usr/bin/env bash
# stepIptvDiag.sh — READ ONLY. How the IPTV worker fetches/parses libraries (OOM source) + how PM2 launches it.
set -uo pipefail
GSZ=/opt/gsz; W=$GSZ/lib/iptv/worker.js

echo "===== worker.js size + structure ====="
wc -l "$W" 2>/dev/null
grep -nE "require\(|function |=>|m3u|M3U|player_api|get\.php|parse|\.match|\.split|replace|gzip|fetch|axios|https?\.|download|snapshot|INSERT|UPDATE|maxBuffer|responseType" "$W" 2>/dev/null | head -70

echo; echo "===== the M3U fetch + parse region (the OOM path) ====="
L=$(grep -nE "get\.php|\.m3u|M3U|parseM3U|#EXTINF|responseType|maxContentLength" "$W" 2>/dev/null | head -1 | cut -d: -f1)
echo "first parse hit near line: ${L:-<none>}"
if [ -n "${L:-}" ]; then sed -n "$((L>8?L-8:1)),$((L+70))p" "$W"; fi

echo; echo "===== any iptv lib files involved ====="
ls -1 "$GSZ/lib/iptv/" 2>/dev/null

echo; echo "===== how PM2 launches gsz-iptv-worker (interpreter args / heap) ====="
pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{let p=JSON.parse(d).find(x=>x.name==="gsz-iptv-worker");if(!p){console.log("not found");return;}var e=p.pm2_env||{};console.log("exec_path="+(e.pm_exec_path||""));console.log("script="+(e.pm_exec_path||e.script||""));console.log("node_args="+JSON.stringify(e.node_args||e.interpreter_args||[]));console.log("NODE_OPTIONS="+((e.env&&e.env.NODE_OPTIONS)||"(unset)"));console.log("max_memory_restart="+(e.max_memory_restart||"(unset)"));console.log("cwd="+(e.pm_cwd||""));}catch(err){console.log("parse "+err.message);}})'
echo "---- ecosystem files ----"
ls -1 "$GSZ"/ecosystem* 2>/dev/null; grep -rn "iptv-worker\|max-old-space\|max_memory_restart\|node_args" "$GSZ"/ecosystem* 2>/dev/null | head
echo DONE-IPTVDIAG
