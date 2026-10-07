#!/usr/bin/env bash
# GSZ step124 — remove the product-count beside the category name. Idempotent.
set -euo pipefail
GSZ=/opt/gsz; TS=$(date +%Y%m%d-%H%M%S); BK="$GSZ/.bak-step124-$TS"; TMP=$(mktemp -d)
F=views/category.ejs
echo "==> step124: category name — drop product count"
mkdir -p "$BK/$(dirname "$F")"; cp "$GSZ/$F" "$BK/$F"; echo "    backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$F" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTI0IHBhdGNoZXIg4oCUIHJlbW92ZSB0aGUgcHJvZHVjdC1jb3VudCBhZnRlciB0aGUgY2F0ZWdvcnkgbmFtZS4gKi8KY29uc3QgZnMgPSByZXF1aXJlKCdmcycpLCBwYXRoID0gcmVxdWlyZSgncGF0aCcpOwpjb25zdCBST09UID0gcHJvY2Vzcy5hcmd2WzJdOwppZiAoIVJPT1QpIHsgY29uc29sZS5lcnJvcigndXNhZ2U6IHBhdGNoX3N0ZXAxMjQuanMgPGdzei1yb290PicpOyBwcm9jZXNzLmV4aXQoMSk7IH0KZnVuY3Rpb24gcGF0Y2gocmVsLCBlZGl0cykgewogIGNvbnN0IGZpbGUgPSBwYXRoLmpvaW4oUk9PVCwgcmVsKTsgbGV0IHMgPSBmcy5yZWFkRmlsZVN5bmMoZmlsZSwgJ3V0ZjgnKTsKICBmb3IgKGNvbnN0IGUgb2YgZWRpdHMpIHsKICAgIGlmIChzLmluZGV4T2YoZS5ndWFyZCkgPj0gMCkgeyBjb25zb2xlLmxvZygnc2tpcCAoYWxyZWFkeSk6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOyBjb250aW51ZTsgfQogICAgY29uc3QgZmlyc3QgPSBzLmluZGV4T2YoZS5maW5kKTsKICAgIGlmIChmaXJzdCA8IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE1JU1M6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgaWYgKHMuaW5kZXhPZihlLmZpbmQsIGZpcnN0ICsgMSkgPj0gMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTk9UIFVOSVFVRTogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgICBzID0gcy5zbGljZSgwLCBmaXJzdCkgKyBlLnJlcGxhY2UgKyBzLnNsaWNlKGZpcnN0ICsgZS5maW5kLmxlbmd0aCk7CiAgICBjb25zb2xlLmxvZygncGF0Y2hlZDogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgfQogIGZzLndyaXRlRmlsZVN5bmMoZmlsZSwgcyk7Cn0KY29uc3QgRklORCA9ICcgICAgICAgIDxoMj48JT0gY2F0Lm5hbWUgJT4gPHNwYW4gc3R5bGU9ImNvbG9yOnZhcigtLW11dGVkKTtmb250LXdlaWdodDo2MDA7Zm9udC1zaXplOi42ZW0iPig8JT0gdHlwZW9mIHRvdGFsIT09XCd1bmRlZmluZWRcJz90b3RhbDpwcm9kdWN0cy5sZW5ndGggJT4pPC9zcGFuPjwvaDI+JzsKY29uc3QgUkVQTCA9ICcgICAgICAgIDxoMj48JT0gY2F0Lm5hbWUgJT48L2gyPic7CnBhdGNoKCd2aWV3cy9jYXRlZ29yeS5lanMnLCBbCiAgeyBuYW1lOiAnZHJvcC1jb3VudCcsIGd1YXJkOiAnPGgyPjwlPSBjYXQubmFtZSAlPjwvaDI+JywgZmluZDogRklORCwgcmVwbGFjZTogUkVQTCB9Cl0pOwpjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOwo=" | base64 -d > "$TMP/p.js"
echo "==> applying"; node "$TMP/p.js" "$GSZ"
echo "==> validating"; node -e "const ejs=require('$GSZ/node_modules/ejs');ejs.compile(require('fs').readFileSync('$GSZ/$F','utf8'),{filename:'$GSZ/$F'});console.log('    ejs ok')"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz; sleep 2
CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$CODE" = "200" ] && echo "    homepage 200: OK" || { echo "    homepage $CODE"; false; }
trap - ERR; rm -rf "$TMP"
echo ""; echo "==> step124 OK ✅  Category pages show just the name — no product count."
