#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
F="$GSZ/views/account/dashboard.ejs"
TS=$(date +%Y%m%d-%H%M%S)
BK="$F.bak-step166-$TS"
echo "==> step166: fix dashboard cards cut-off on mobile"
cp "$F" "$BK"; echo "    backup: $BK"
restore(){ echo "!! error — restoring"; cp "$BK" "$F" 2>/dev/null || true; }
trap 'restore' ERR
PATCHER=$(mktemp /tmp/patch_step166.XXXXXX.js)
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTY2IOKAlCBmaXggdGhlIGN1c3RvbWVyIGRhc2hib2FyZCBjdXQtb2ZmIG9uIHBob25lcy4gT24gPD04NjBweCB0aGUgZ3JpZAogICBjb2xsYXBzZXMgdG8gb25lIGNvbHVtbiwgYnV0IGEgZmxleCBjaGlsZCdzIGxvbmcgY29udGVudCAob3JkZXIgbmFtZXMsIGVtYWlsLAogICBXaGF0c0FwcCkgc2V0IGEgd2lkZSBtaW4tY29udGVudCBhbmQgcHVzaGVkIHRoZSBhc2lkZSBjYXJkcyBvZmYgdGhlIHJpZ2h0IGVkZ2UuCiAgIEFkZCBtaW4td2lkdGg6MCB0byB0aGUgZ3JpZC9mbGV4IGNoaWxkcmVuIHNvIHRoZXkgc2hyaW5rIGFuZCBlbGxpcHNpcyB3b3Jrcy4KICAgSWRlbXBvdGVudC4gKi8KY29uc3QgZnMgPSByZXF1aXJlKCdmcycpOyBjb25zdCBwYXRoID0gcmVxdWlyZSgncGF0aCcpOwpjb25zdCBST09UID0gcHJvY2Vzcy5hcmd2WzJdOyBpZiAoIVJPT1QpIHsgY29uc29sZS5lcnJvcigndXNhZ2UnKTsgcHJvY2Vzcy5leGl0KDEpOyB9CmZ1bmN0aW9uIHBhdGNoKHJlbCwgZWRpdHMpIHsKICBjb25zdCBmaWxlID0gcGF0aC5qb2luKFJPT1QsIHJlbCk7IGxldCBzID0gZnMucmVhZEZpbGVTeW5jKGZpbGUsICd1dGY4Jyk7CiAgZm9yIChjb25zdCBlIG9mIGVkaXRzKSB7CiAgICBpZiAocy5pbmRleE9mKGUuZ3VhcmQpID49IDApIHsgY29uc29sZS5sb2coJ3NraXAgKGFscmVhZHkpOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsgY29udGludWU7IH0KICAgIGNvbnN0IGZpcnN0ID0gcy5pbmRleE9mKGUuZmluZCk7CiAgICBpZiAoZmlyc3QgPCAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBNSVNTOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIGlmIChzLmluZGV4T2YoZS5maW5kLCBmaXJzdCArIDEpID49IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE5PVCBVTklRVUU6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgcyA9IHMuc2xpY2UoMCwgZmlyc3QpICsgZS5yZXBsYWNlICsgcy5zbGljZShmaXJzdCArIGUuZmluZC5sZW5ndGgpOwogICAgY29uc29sZS5sb2coJ3BhdGNoZWQ6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogIH0KICBmcy53cml0ZUZpbGVTeW5jKGZpbGUsIHMpOwp9CnBhdGNoKCd2aWV3cy9hY2NvdW50L2Rhc2hib2FyZC5lanMnLCBbCiAgeyBuYW1lOiAnbW9iaWxlLW1pbndpZHRoJywKICAgIGd1YXJkOiAnLmFjYy1ncmlkPip7bWluLXdpZHRoOjB9JywKICAgIGZpbmQ6ICdAbWVkaWEobWF4LXdpZHRoOjg2MHB4KXsuYWNjLWdyaWR7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmcn19JywKICAgIHJlcGxhY2U6ICdAbWVkaWEobWF4LXdpZHRoOjg2MHB4KXsuYWNjLWdyaWR7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmcn0uYWNjLWdyaWQ+KnttaW4td2lkdGg6MH0ub3Jke21pbi13aWR0aDowfS5vcmQ+KnttaW4td2lkdGg6MH0ucWF7bWluLXdpZHRoOjB9LnFhIC5xdHttaW4td2lkdGg6MH0uZHJvdyAudnttaW4td2lkdGg6MDt3b3JkLWJyZWFrOmJyZWFrLXdvcmR9fScgfQpdKTsKY29uc29sZS5sb2coJ0FMTCBQQVRDSEVTIEFQUExJRUQnKTsK" | base64 -d > "$PATCHER"
echo "==> applying"; NODE_PATH="$GSZ/node_modules" node "$PATCHER" "$GSZ"
echo "==> validating"; NODE_PATH="$GSZ/node_modules" node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$F','utf8'),{filename:'$F'});console.log('    ejs ok')"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000; for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    homepage $CODE after ${i}s"; false; }
echo "    homepage 200: OK (after ${i}s)"
rm -f "$PATCHER"; trap - ERR
echo ""
echo "==> step166 OK  Customer dashboard no longer cuts off the Quick Actions and Your-details cards on phones — the full email, Verified badge and chevrons now fit. Hard-refresh once."
