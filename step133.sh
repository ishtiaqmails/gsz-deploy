#!/usr/bin/env bash
# GSZ step133 — category pages show 24 products per page (was 12). The no-reload
# pagination (no jump-to-top) ships next once app.js is confirmed. Idempotent.
set -euo pipefail
GSZ=/opt/gsz; TS=$(date +%Y%m%d-%H%M%S); BK="$GSZ/.bak-step133-$TS"; TMP=$(mktemp -d)
FILES=(routes/category.js)
echo "==> step133: 24 products per category page"
mkdir -p "$BK"; for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
echo "    backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTMzIHBhdGNoZXIg4oCUIGNhdGVnb3J5IHBhZ2VzIHNob3cgMjQgcHJvZHVjdHMgcGVyIHBhZ2UgKHdhcyAxMikuIFRoZQogICAibm8ganVtcCBvbiBwYWdpbmF0aW9uIiBBSkFYIHNoaXBzIHNlcGFyYXRlbHkuIElkZW1wb3RlbnQuICovCmNvbnN0IGZzID0gcmVxdWlyZSgnZnMnKTsgY29uc3QgcGF0aCA9IHJlcXVpcmUoJ3BhdGgnKTsKY29uc3QgUk9PVCA9IHByb2Nlc3MuYXJndlsyXTsgaWYgKCFST09UKSB7IGNvbnNvbGUuZXJyb3IoJ3VzYWdlOiBwYXRjaF9zdGVwMTMzLmpzIDxnc3otcm9vdD4nKTsgcHJvY2Vzcy5leGl0KDEpOyB9CmZ1bmN0aW9uIHBhdGNoKHJlbCwgZWRpdHMpIHsKICBjb25zdCBmaWxlID0gcGF0aC5qb2luKFJPT1QsIHJlbCk7IGxldCBzID0gZnMucmVhZEZpbGVTeW5jKGZpbGUsICd1dGY4Jyk7CiAgZm9yIChjb25zdCBlIG9mIGVkaXRzKSB7CiAgICBpZiAocy5pbmRleE9mKGUuZ3VhcmQpID49IDApIHsgY29uc29sZS5sb2coJ3NraXAgKGFscmVhZHkpOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsgY29udGludWU7IH0KICAgIGNvbnN0IGZpcnN0ID0gcy5pbmRleE9mKGUuZmluZCk7CiAgICBpZiAoZmlyc3QgPCAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBNSVNTOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIGlmIChzLmluZGV4T2YoZS5maW5kLCBmaXJzdCArIDEpID49IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE5PVCBVTklRVUU6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgcyA9IHMuc2xpY2UoMCwgZmlyc3QpICsgZS5yZXBsYWNlICsgcy5zbGljZShmaXJzdCArIGUuZmluZC5sZW5ndGgpOwogICAgY29uc29sZS5sb2coJ3BhdGNoZWQ6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogIH0KICBmcy53cml0ZUZpbGVTeW5jKGZpbGUsIHMpOwp9CnBhdGNoKCdyb3V0ZXMvY2F0ZWdvcnkuanMnLCBbCiAgeyBuYW1lOiAncGVyLXBhZ2UtMjQnLCBndWFyZDogJ2NvbnN0IHBlclBhZ2UgPSAyNDsnLCBmaW5kOiAnY29uc3QgcGVyUGFnZSA9IDEyOycsIHJlcGxhY2U6ICdjb25zdCBwZXJQYWdlID0gMjQ7JyB9Cl0pOwpjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOwo=" | base64 -d > "$TMP/p.js"
echo "==> applying"; node "$TMP/p.js" "$GSZ"
echo "==> validating"; node --check "$GSZ/routes/category.js"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz; sleep 2
CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$CODE" = "200" ] && echo "    homepage 200: OK" || { echo "    homepage $CODE"; false; }
trap - ERR; rm -rf "$TMP"
echo ""; echo "==> step133 OK ✅  Category pages now show 24 products before paginating."
