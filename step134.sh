#!/usr/bin/env bash
# GSZ step134 — add "Issues" link to the admin sidebar (Sales group). Finishes
# step131's /admin/issues page. One view patch, no migration. Idempotent.
set -euo pipefail
GSZ=/opt/gsz; TS=$(date +%Y%m%d-%H%M%S); BK="$GSZ/.bak-step134-$TS"; TMP=$(mktemp -d)
FILES=(views/admin/_shell_top.ejs)
echo "==> step134: Issues nav link"
mkdir -p "$BK"; for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
echo "    backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTM0IHBhdGNoZXIg4oCUIGFkZCBhbiAiSXNzdWVzIiBsaW5rIHRvIHRoZSBhZG1pbiBzaWRlYmFyIChTYWxlcyBncm91cCksCiAgIHJpZ2h0IGFmdGVyIFBheW1lbnRzLiBIaWdobGlnaHRzIHZpYSBvbignaXNzdWVzJykuIElkZW1wb3RlbnQuICovCmNvbnN0IGZzID0gcmVxdWlyZSgnZnMnKTsgY29uc3QgcGF0aCA9IHJlcXVpcmUoJ3BhdGgnKTsKY29uc3QgUk9PVCA9IHByb2Nlc3MuYXJndlsyXTsgaWYgKCFST09UKSB7IGNvbnNvbGUuZXJyb3IoJ3VzYWdlOiBwYXRjaF9zdGVwMTM0LmpzIDxnc3otcm9vdD4nKTsgcHJvY2Vzcy5leGl0KDEpOyB9CmZ1bmN0aW9uIHBhdGNoKHJlbCwgZWRpdHMpIHsKICBjb25zdCBmaWxlID0gcGF0aC5qb2luKFJPT1QsIHJlbCk7IGxldCBzID0gZnMucmVhZEZpbGVTeW5jKGZpbGUsICd1dGY4Jyk7CiAgZm9yIChjb25zdCBlIG9mIGVkaXRzKSB7CiAgICBpZiAocy5pbmRleE9mKGUuZ3VhcmQpID49IDApIHsgY29uc29sZS5sb2coJ3NraXAgKGFscmVhZHkpOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsgY29udGludWU7IH0KICAgIGNvbnN0IGZpcnN0ID0gcy5pbmRleE9mKGUuZmluZCk7CiAgICBpZiAoZmlyc3QgPCAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBNSVNTOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIGlmIChzLmluZGV4T2YoZS5maW5kLCBmaXJzdCArIDEpID49IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE5PVCBVTklRVUU6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgcyA9IHMuc2xpY2UoMCwgZmlyc3QpICsgZS5yZXBsYWNlICsgcy5zbGljZShmaXJzdCArIGUuZmluZC5sZW5ndGgpOwogICAgY29uc29sZS5sb2coJ3BhdGNoZWQ6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogIH0KICBmcy53cml0ZUZpbGVTeW5jKGZpbGUsIHMpOwp9CmNvbnN0IEZJTkQgPSAnICAgIDxhIGhyZWY9Ii9hZG1pbi9wYXltZW50cyIgY2xhc3M9IjwlPSBvbihcJ3BheW1lbnRzXCcpICU+Ij48c3ZnIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHJlY3QgeD0iMiIgeT0iNSIgd2lkdGg9IjIwIiBoZWlnaHQ9IjE0IiByeD0iMiIvPjxwYXRoIGQ9Ik0yIDEwaDIwIi8+PC9zdmc+UGF5bWVudHM8L2E+JzsKY29uc3QgUkVQTCA9IEZJTkQgKyAnXG4nCiAgKyAnICAgIDxhIGhyZWY9Ii9hZG1pbi9pc3N1ZXMiIGNsYXNzPSI8JT0gb24oXCdpc3N1ZXNcJykgJT4iPjxzdmcgdmlld0JveD0iMCAwIDI0IDI0Ij48cGF0aCBkPSJNMTAuMyAzLjkgMiAxOGEyIDIgMCAwIDAgMS43IDNoMTYuNmEyIDIgMCAwIDAgMS43LTNMMTMuNyAzLjlhMiAyIDAgMCAwLTMuNCAweiIvPjxwYXRoIGQ9Ik0xMiA5djQiLz48cGF0aCBkPSJNMTIgMTdoLjAxIi8+PC9zdmc+SXNzdWVzPC9hPic7CnBhdGNoKCd2aWV3cy9hZG1pbi9fc2hlbGxfdG9wLmVqcycsIFsKICB7IG5hbWU6ICdpc3N1ZXMtbmF2JywgZ3VhcmQ6ICcvYWRtaW4vaXNzdWVzJywgZmluZDogRklORCwgcmVwbGFjZTogUkVQTCB9Cl0pOwpjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOwo=" | base64 -d > "$TMP/p.js"
echo "==> applying"; node "$TMP/p.js" "$GSZ"
echo "==> validating"; node -e "const ejs=require('$GSZ/node_modules/ejs');ejs.compile(require('fs').readFileSync('$GSZ/views/admin/_shell_top.ejs','utf8'),{filename:'s'});console.log('    ejs ok')"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz; sleep 2
CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$CODE" = "200" ] && echo "    homepage 200: OK" || { echo "    homepage $CODE"; false; }
trap - ERR; rm -rf "$TMP"
echo ""; echo "==> step134 OK ✅  'Issues' now appears in the admin sidebar (under Sales)."
