#!/usr/bin/env bash
# gsz-stepB1gAgentXT : b1g serves a CLIPPED get.php M3U (~12k) while its player_api carries the full
# catalog (~26k). Force b1g's phone pull straight to player_api by skipping the M3U route for that
# panel only. Edits the server-served agent.sh (phone auto-re-fetches it). Safe: backup,guard,revert.
set -e
cd /opt/gsz
F=lib/iptv/agent.sh
cp "$F" /opt/gsz/.gsz-b1gagent.bak

cat > /tmp/gsz_agent_patch.js <<'PATCH'
const fs=require('fs');
const f='/opt/gsz/lib/iptv/agent.sh';
let s=fs.readFileSync(f,'utf8');
function rep(o,n){ const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+': '+o.slice(0,46)); process.exit(5); } s=s.replace(o,()=>n); }

rep(
'  [ -z "$M3U" ] && { echo "$(ts) [$1] no order/trial yet - skipping"; return 2; }\n  curl -s --max-time 1800 --compressed -o "$TMP/lib.m3u" "$M3U" 2>/dev/null',
'  [ -z "$M3U" ] && { echo "$(ts) [$1] no order/trial yet - skipping"; return 2; }\n  # some panels serve a CLIPPED get.php M3U (b1g ~12k) while player_api carries the full catalog (~26k) - force those to player_api.\n  FORCE_XT=0; case "$1" in b1g-tv-iptv) FORCE_XT=1 ;; esac\n  if [ "$FORCE_XT" = "0" ]; then\n  curl -s --max-time 1800 --compressed -o "$TMP/lib.m3u" "$M3U" 2>/dev/null'
);

rep(
'  echo "$(ts) [$1] get.php empty (${SZ}b) - trying player_api..."\n  HOST=$(printf',
'  echo "$(ts) [$1] get.php empty (${SZ}b) - trying player_api..."\n  fi\n  HOST=$(printf'
);

fs.writeFileSync(f,s);
console.log('PATCHED OK');
PATCH

node /tmp/gsz_agent_patch.js || { echo "patch failed - reverting"; cp /opt/gsz/.gsz-b1gagent.bak "$F"; exit 1; }
sh -n "$F" || { echo "shell syntax error - reverting"; cp /opt/gsz/.gsz-b1gagent.bak "$F"; exit 1; }

pm2 restart gsz
echo "DONE: b1g phone pull now uses player_api (full catalog). Re-fetch the agent on the phone, then sweep."
