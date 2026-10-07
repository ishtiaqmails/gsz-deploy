#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
F="$GSZ/views/partials/store_bottom.ejs"
TS=$(date +%Y%m%d-%H%M%S)
BK="$F.bak-step165-$TS"
echo "==> step165: trials modal polish (fix leaked text + compact/scroll)"
cp "$F" "$BK"; echo "    backup: $BK"
restore(){ echo "!! error — restoring"; cp "$BK" "$F" 2>/dev/null || true; }
trap 'restore' ERR
PATCHER=$(mktemp /tmp/patch_step165.XXXXXX.js)
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTY1IOKAlCB0cmlhbHMgbW9kYWwgcG9saXNoOiBmaXggdGhlIGxlYWtlZCDigJkgZXNjYXBlIGluIHRoZSBzdWJ0aXRsZSAoaXQKICAgc2hvd2VkIGxpdGVyYWwgIndl4oCZbGwiKSwgY2FwIHRoZSBsaXN0IGhlaWdodCBzbyB0aGUgbW9kYWwgbmV2ZXIgcnVucyBvZmYgYQogICBwaG9uZSBzY3JlZW4sIGFuZCB0aWdodGVuIGVhY2ggcm93LiBJZGVtcG90ZW50LiAqLwpjb25zdCBmcyA9IHJlcXVpcmUoJ2ZzJyk7IGNvbnN0IHBhdGggPSByZXF1aXJlKCdwYXRoJyk7CmNvbnN0IFJPT1QgPSBwcm9jZXNzLmFyZ3ZbMl07IGlmICghUk9PVCkgeyBjb25zb2xlLmVycm9yKCd1c2FnZScpOyBwcm9jZXNzLmV4aXQoMSk7IH0KZnVuY3Rpb24gcGF0Y2gocmVsLCBlZGl0cykgewogIGNvbnN0IGZpbGUgPSBwYXRoLmpvaW4oUk9PVCwgcmVsKTsgbGV0IHMgPSBmcy5yZWFkRmlsZVN5bmMoZmlsZSwgJ3V0ZjgnKTsKICBmb3IgKGNvbnN0IGUgb2YgZWRpdHMpIHsKICAgIGlmIChzLmluZGV4T2YoZS5ndWFyZCkgPj0gMCkgeyBjb25zb2xlLmxvZygnc2tpcCAoYWxyZWFkeSk6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOyBjb250aW51ZTsgfQogICAgY29uc3QgZmlyc3QgPSBzLmluZGV4T2YoZS5maW5kKTsKICAgIGlmIChmaXJzdCA8IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE1JU1M6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgaWYgKHMuaW5kZXhPZihlLmZpbmQsIGZpcnN0ICsgMSkgPj0gMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTk9UIFVOSVFVRTogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgICBzID0gcy5zbGljZSgwLCBmaXJzdCkgKyBlLnJlcGxhY2UgKyBzLnNsaWNlKGZpcnN0ICsgZS5maW5kLmxlbmd0aCk7CiAgICBjb25zb2xlLmxvZygncGF0Y2hlZDogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgfQogIGZzLndyaXRlRmlsZVN5bmMoZmlsZSwgcyk7Cn0KCnBhdGNoKCd2aWV3cy9wYXJ0aWFscy9zdG9yZV9ib3R0b20uZWpzJywgWwogIHsgbmFtZTogJ3N1YnRpdGxlLWZpeCcsCiAgICBndWFyZDogIndlJ2xsIHNlbmQgaXQgdG8geW91ciBXaGF0c0FwcCIsCiAgICBmaW5kOiAiUGljayBhIHNlcnZpY2UgYmVsb3cg4oCUIHdlXFx1MjAxOWxsIHNlbmQgaXQgdG8geW91ciBXaGF0c0FwcC4iLAogICAgcmVwbGFjZTogIlBpY2sgYSBzZXJ2aWNlIGJlbG93IOKAlCB3ZSdsbCBzZW5kIGl0IHRvIHlvdXIgV2hhdHNBcHAuIiB9LAoKICB7IG5hbWU6ICdsaXN0LWNhcCcsCiAgICBndWFyZDogJ21heC1oZWlnaHQ6NTJ2aCcsCiAgICBmaW5kOiAnLnRyaWFsbS1saXN0e2Rpc3BsYXk6Z3JpZDtnYXA6MTBweH0nLAogICAgcmVwbGFjZTogJy50cmlhbG0tbGlzdHtkaXNwbGF5OmdyaWQ7Z2FwOjhweDttYXgtaGVpZ2h0OjUydmg7b3ZlcmZsb3cteTphdXRvOy13ZWJraXQtb3ZlcmZsb3ctc2Nyb2xsaW5nOnRvdWNoO21hcmdpbjowIC00cHg7cGFkZGluZzowIDRweH0nIH0sCgogIHsgbmFtZTogJ2l0ZW0tdGlnaHRlbicsCiAgICBndWFyZDogJy50cmlhbG0taXRlbXtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMHB4JywKICAgIGZpbmQ6ICcudHJpYWxtLWl0ZW17ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6MTJweDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUsI2U3ZWJmNik7Ym9yZGVyLXJhZGl1czoxNHB4O3BhZGRpbmc6MTJweCAxNHB4fScsCiAgICByZXBsYWNlOiAnLnRyaWFsbS1pdGVte2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjEwcHg7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lLCNlN2ViZjYpO2JvcmRlci1yYWRpdXM6MTJweDtwYWRkaW5nOjlweCAxMnB4fScgfQpdKTsKCmNvbnNvbGUubG9nKCdBTEwgUEFUQ0hFUyBBUFBMSUVEJyk7Cg==" | base64 -d > "$PATCHER"
echo "==> applying"
NODE_PATH="$GSZ/node_modules" node "$PATCHER" "$GSZ"
echo "==> validating"
NODE_PATH="$GSZ/node_modules" node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$F','utf8'),{filename:'$F'});console.log('    ejs ok')"
echo "==> restarting"
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000
for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    homepage $CODE after ${i}s"; false; }
echo "    homepage 200: OK (after ${i}s)"
rm -f "$PATCHER"
trap - ERR
echo ""
echo "==> step165 OK  Trial modal: fixed the garbled subtitle text, and the list now scrolls inside a capped height so it fits any phone. Hard-refresh once."
