#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-step153-$TS"
echo "==> step153: email verification optional (WhatsApp is enough)"
echo "    backup: $BK"
mkdir -p "$BK/routes" "$BK/views/account"
cp "$GSZ/routes/account.js" "$BK/routes/" 2>/dev/null || true
cp "$GSZ/views/account/dashboard.ejs" "$BK/views/account/" 2>/dev/null || true

restore(){ echo "!! error — restoring"; cp "$BK/routes/account.js" "$GSZ/routes/" 2>/dev/null || true; cp "$BK/views/account/dashboard.ejs" "$GSZ/views/account/" 2>/dev/null || true; }
trap 'restore' ERR

PATCHER=$(mktemp /tmp/patch_step153.XXXXXX.js)
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTUzIOKAlCBlbWFpbCB2ZXJpZmljYXRpb24gaXMgT1BUSU9OQUwgKFdoYXRzQXBwIHZlcmlmaWNhdGlvbiBpcyBlbm91Z2gpLgogICAtIGFjY291bnQuanM6IGFmdGVyIHNpZ24tdXAsIGxhbmQgdGhlIGN1c3RvbWVyIHN0cmFpZ2h0IGluIC9hY2NvdW50IGluc3RlYWQgb2YKICAgICBmb3JjaW5nIHRoZSB2ZXJpZnktZW1haWwgcGFnZSAod2hpY2ggYmxvY2tlZCB0aGVtIHdoZW4gbWFpbCB3YXNuJ3Qgc2V0IHVwKS4KICAgLSBkYXNoYm9hcmQuZWpzOiBuZXZlciBuYWcgZm9yIGVtYWlsIHZlcmlmaWNhdGlvbjsga2VlcCB0aGUgV2hhdHNBcHAgbnVkZ2UuCiAgICAgVGhlIGVtYWlsIHJvdyBzaG93cyAiVmVyaWZpZWQiIG9ubHkgd2hlbiB2ZXJpZmllZCwgbm8gIlZlcmlmeSIgcHJvbXB0LgogICBJZGVtcG90ZW50LiBUaGUgL2FjY291bnQvdmVyaWZ5LWVtYWlsIHJvdXRlIHN0YXlzIGF2YWlsYWJsZSBmb3IgYW55b25lIHdobwogICBzdGlsbCB3YW50cyB0byB2ZXJpZnksIGl0IGlzIGp1c3QgbmV2ZXIgZm9yY2VkLiAqLwpjb25zdCBmcyA9IHJlcXVpcmUoJ2ZzJyk7IGNvbnN0IHBhdGggPSByZXF1aXJlKCdwYXRoJyk7CmNvbnN0IFJPT1QgPSBwcm9jZXNzLmFyZ3ZbMl07IGlmICghUk9PVCkgeyBjb25zb2xlLmVycm9yKCd1c2FnZTogbm9kZSBwYXRjaF9zdGVwMTUzLmpzIDxnc3otcm9vdD4nKTsgcHJvY2Vzcy5leGl0KDEpOyB9CmZ1bmN0aW9uIHBhdGNoKHJlbCwgZWRpdHMpIHsKICBjb25zdCBmaWxlID0gcGF0aC5qb2luKFJPT1QsIHJlbCk7IGxldCBzID0gZnMucmVhZEZpbGVTeW5jKGZpbGUsICd1dGY4Jyk7CiAgZm9yIChjb25zdCBlIG9mIGVkaXRzKSB7CiAgICBpZiAocy5pbmRleE9mKGUuZ3VhcmQpID49IDApIHsgY29uc29sZS5sb2coJ3NraXAgKGFscmVhZHkpOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsgY29udGludWU7IH0KICAgIGNvbnN0IGZpcnN0ID0gcy5pbmRleE9mKGUuZmluZCk7CiAgICBpZiAoZmlyc3QgPCAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBNSVNTOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIGlmIChzLmluZGV4T2YoZS5maW5kLCBmaXJzdCArIDEpID49IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE5PVCBVTklRVUU6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgcyA9IHMuc2xpY2UoMCwgZmlyc3QpICsgZS5yZXBsYWNlICsgcy5zbGljZShmaXJzdCArIGUuZmluZC5sZW5ndGgpOwogICAgY29uc29sZS5sb2coJ3BhdGNoZWQ6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogIH0KICBmcy53cml0ZUZpbGVTeW5jKGZpbGUsIHMpOwp9CgovKiBhY2NvdW50LmpzIOKAlCBzaWdudXAgbGFuZHMgaW4gL2FjY291bnQsIG5vdCB2ZXJpZnktZW1haWwgKi8KY29uc3QgQV9GSU5EID0KIiAgICAgIGlmIChhamF4KSByZXR1cm4gcmVzLmpzb24oeyBvazp0cnVlLCByZWRpcmVjdDogJy9hY2NvdW50L3ZlcmlmeS1lbWFpbCcgfSk7XG4iICsKIiAgICAgIHJlcy5yZWRpcmVjdCgnL2FjY291bnQvdmVyaWZ5LWVtYWlsJyk7IjsKY29uc3QgQV9SRVBMID0KIiAgICAgIGlmIChhamF4KSByZXR1cm4gcmVzLmpzb24oeyBvazp0cnVlLCByZWRpcmVjdDogJy9hY2NvdW50JyB9KTsgLypub0VtYWlsVmVyaWZ5Ki9cbiIgKwoiICAgICAgcmVzLnJlZGlyZWN0KCcvYWNjb3VudCcpOyI7CgpwYXRjaCgncm91dGVzL2FjY291bnQuanMnLCBbCiAgeyBuYW1lOiAnc2lnbnVwLW5vLXZlcmlmeScsIGd1YXJkOiAnLypub0VtYWlsVmVyaWZ5Ki8nLCBmaW5kOiBBX0ZJTkQsIHJlcGxhY2U6IEFfUkVQTCB9Cl0pOwoKLyogZGFzaGJvYXJkLmVqcyDigJQgZW1haWwgdmVyaWZpY2F0aW9uIG5ldmVyIG5hZ2dlZCAqLwpjb25zdCBEMV9GSU5EID0gInZhciBuZWVkRW1haWwgPSAhYy5lbWFpbF92ZXJpZmllZCwgbmVlZFdhID0gIXdhT2s7IjsKY29uc3QgRDFfUkVQTCA9ICJ2YXIgbmVlZEVtYWlsID0gZmFsc2UgLyp3YU9ubHlWZXJpZnkqLywgbmVlZFdhID0gIXdhT2s7IjsKCmNvbnN0IEQyX0ZJTkQgPSAnPCUgaWYgKGMuZW1haWxfdmVyaWZpZWQpIHsgJT48c3BhbiBjbGFzcz0idmJhZGdlIG9rIj5WZXJpZmllZDwvc3Bhbj48JSB9IGVsc2UgeyAlPjxhIGhyZWY9Ii9hY2NvdW50L3ZlcmlmeS1lbWFpbCIgY2xhc3M9InZiYWRnZSBubyIgc3R5bGU9InRleHQtZGVjb3JhdGlvbjpub25lIj5WZXJpZnk8L2E+PCUgfSAlPic7CmNvbnN0IEQyX1JFUEwgPSAnPCUgaWYgKGMuZW1haWxfdmVyaWZpZWQpIHsgJT48c3BhbiBjbGFzcz0idmJhZGdlIG9rIj5WZXJpZmllZDwvc3Bhbj48JSB9ICU+PCUvKmVtYWlsTm9OYWcqLyU+JzsKCnBhdGNoKCd2aWV3cy9hY2NvdW50L2Rhc2hib2FyZC5lanMnLCBbCiAgeyBuYW1lOiAnd2Etb25seS1mbGFnJywgZ3VhcmQ6ICcvKndhT25seVZlcmlmeSovJywgZmluZDogRDFfRklORCwgcmVwbGFjZTogRDFfUkVQTCB9LAogIHsgbmFtZTogJ2VtYWlsLW5vLW5hZycsIGd1YXJkOiAnZW1haWxOb05hZycsIGZpbmQ6IEQyX0ZJTkQsIHJlcGxhY2U6IEQyX1JFUEwgfQpdKTsKCmNvbnNvbGUubG9nKCdBTEwgUEFUQ0hFUyBBUFBMSUVEJyk7Cg==" | base64 -d > "$PATCHER"

echo "==> applying"
NODE_PATH="$GSZ/node_modules" node "$PATCHER" "$GSZ"

echo "==> validating"
node --check "$GSZ/routes/account.js"
NODE_PATH="$GSZ/node_modules" node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/views/account/dashboard.ejs','utf8'),{filename:'$GSZ/views/account/dashboard.ejs'});console.log('    ejs ok')"

echo "==> restarting"
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000
for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    homepage $CODE after ${i}s"; false; }
echo "    homepage 200: OK (after ${i}s)"

rm -f "$PATCHER"
trap - ERR
echo ""
echo "==> step153 OK  New sign-ups now go straight into their account — no forced email step. The dashboard only nudges for WhatsApp; email never nags. (Email verify page still exists for anyone who wants it, just never forced.)"
