#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/routes/trials.js.bak-step162-$TS"
echo "==> step162: remove email gate on free trials (real #1 fix)"
cp "$GSZ/routes/trials.js" "$BK"; echo "    backup: $BK"
restore(){ echo "!! error — restoring"; cp "$BK" "$GSZ/routes/trials.js" 2>/dev/null || true; }
trap 'restore' ERR
PATCHER=$(mktemp /tmp/patch_step162.XXXXXX.js)
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTYyIOKAlCByZWFsIGZpeCBmb3IgIzEuIHRyaWFscy5qcyBhbHJlYWR5IGhhZCBhIFdoYXRzQXBwIGdhdGUgKHYud2FPaykgcmlnaHQKICAgQUZURVIgYW4gZW1haWwgZ2F0ZSAodi5lbWFpbE9rIC0+IC9hY2NvdW50L3ZlcmlmeS1lbWFpbCkuIHN0ZXAxNjEncyBndWFyZCBtYXRjaGVkCiAgIHRoZSBwcmUtZXhpc3Rpbmcgd2FPayBsaW5lIGFuZCBza2lwcGVkLCBzbyB0aGUgZW1haWwgZ2F0ZSBzdGF5ZWQuIFJlbW92ZSB0aGUKICAgZW1haWwgZ2F0ZSBvdXRyaWdodDsgdGhlIHdhT2sgZ2F0ZSBiZWxvdyBpdCBhbHJlYWR5IGVuZm9yY2VzIFdoYXRzQXBwLiBJZGVtcG90ZW50LiAqLwpjb25zdCBmcyA9IHJlcXVpcmUoJ2ZzJyk7IGNvbnN0IHBhdGggPSByZXF1aXJlKCdwYXRoJyk7CmNvbnN0IFJPT1QgPSBwcm9jZXNzLmFyZ3ZbMl07IGlmICghUk9PVCkgeyBjb25zb2xlLmVycm9yKCd1c2FnZScpOyBwcm9jZXNzLmV4aXQoMSk7IH0KZnVuY3Rpb24gcGF0Y2gocmVsLCBlZGl0cykgewogIGNvbnN0IGZpbGUgPSBwYXRoLmpvaW4oUk9PVCwgcmVsKTsgbGV0IHMgPSBmcy5yZWFkRmlsZVN5bmMoZmlsZSwgJ3V0ZjgnKTsKICBmb3IgKGNvbnN0IGUgb2YgZWRpdHMpIHsKICAgIGlmIChzLmluZGV4T2YoZS5ndWFyZCkgPj0gMCkgeyBjb25zb2xlLmxvZygnc2tpcCAoYWxyZWFkeSk6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOyBjb250aW51ZTsgfQogICAgY29uc3QgZmlyc3QgPSBzLmluZGV4T2YoZS5maW5kKTsKICAgIGlmIChmaXJzdCA8IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE1JU1M6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgaWYgKHMuaW5kZXhPZihlLmZpbmQsIGZpcnN0ICsgMSkgPj0gMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTk9UIFVOSVFVRTogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgICBzID0gcy5zbGljZSgwLCBmaXJzdCkgKyBlLnJlcGxhY2UgKyBzLnNsaWNlKGZpcnN0ICsgZS5maW5kLmxlbmd0aCk7CiAgICBjb25zb2xlLmxvZygncGF0Y2hlZDogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgfQogIGZzLndyaXRlRmlsZVN5bmMoZmlsZSwgcyk7Cn0KcGF0Y2goJ3JvdXRlcy90cmlhbHMuanMnLCBbCiAgeyBuYW1lOiAnZHJvcC1lbWFpbC1nYXRlJywKICAgIGd1YXJkOiAndHJpYWxOb0VtYWlsR2F0ZScsCiAgICBmaW5kOiAiaWYgKCF2LmVtYWlsT2spIHJldHVybiByZXMucmVkaXJlY3QoJy9hY2NvdW50L3ZlcmlmeS1lbWFpbCcpOyIsCiAgICByZXBsYWNlOiAiLyogZW1haWwgbm90IHJlcXVpcmVkIGZvciB0cmlhbHMg4oCUIFdoYXRzQXBwIGlzIHRoZSBnYXRlICh0cmlhbE5vRW1haWxHYXRlKSAqLyIgfQpdKTsKY29uc29sZS5sb2coJ0FMTCBQQVRDSEVTIEFQUExJRUQnKTsK" | base64 -d > "$PATCHER"
echo "==> applying"
NODE_PATH="$GSZ/node_modules" node "$PATCHER" "$GSZ"
echo "==> validating"
node --check "$GSZ/routes/trials.js" && echo "    node --check ok"
grep -q "account/verify-email" "$GSZ/routes/trials.js" && echo "    WARN: a verify-email ref still present" || echo "    confirmed: no verify-email redirect left in trials.js"
echo "==> restarting"
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000
for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    homepage $CODE after ${i}s"; false; }
echo "    homepage 200: OK (after ${i}s)"
rm -f "$PATCHER"
trap - ERR
echo ""
echo "==> step162 OK  Free trials no longer ask for email verification at all — only WhatsApp. (This is the fix step161 was meant to make; its guard had matched a pre-existing line and skipped.)"
