#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-step169-$TS"
echo "==> step169: Browse hover+click + hide trial-modal scrollbar"
mkdir -p "$BK/views/partials"
cp "$GSZ/views/partials/store_top.ejs" "$BK/views/partials/" 2>/dev/null||true
cp "$GSZ/views/partials/store_bottom.ejs" "$BK/views/partials/" 2>/dev/null||true
echo "    backup: $BK"
restore(){ echo "!! restoring"; cp "$BK/views/partials/store_top.ejs" "$GSZ/views/partials/" 2>/dev/null||true; cp "$BK/views/partials/store_bottom.ejs" "$GSZ/views/partials/" 2>/dev/null||true; }
trap 'restore' ERR
PATCHER=$(mktemp /tmp/patch_step169.XXXXXX.js); echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTY5IOKAlCBVSSBwb2xpc2g6CiAgIC0gc3RvcmVfdG9wLmVqczogQnJvd3NlIGRyb3Bkb3duIG9wZW5zIG9uIEhPVkVSIHRvbyAoaG92ZXItY2FwYWJsZSBkZXZpY2VzKSwKICAgICBpbiBhZGRpdGlvbiB0byBjbGljayAoY2xpY2sgc3RpbGwgdG9nZ2xlcy9waW5zIGl0KS4KICAgLSBzdG9yZV9ib3R0b20uZWpzOiBoaWRlIHRoZSB0cmlhbHMtbW9kYWwgaW5uZXIgc2Nyb2xsYmFyIChrZWVwIHNtb290aCBzY3JvbGwpCiAgICAgYW5kIGdpdmUgaXQgYSBsaXR0bGUgbW9yZSBoZWlnaHQsIHNvIGl0IG5vIGxvbmdlciBzaG93cyBhbiB1Z2x5IHNjcm9sbGJhci4KICAgSWRlbXBvdGVudC4gKi8KY29uc3QgZnMgPSByZXF1aXJlKCdmcycpOyBjb25zdCBwYXRoID0gcmVxdWlyZSgncGF0aCcpOwpjb25zdCBST09UID0gcHJvY2Vzcy5hcmd2WzJdOyBpZiAoIVJPT1QpIHsgY29uc29sZS5lcnJvcigndXNhZ2UnKTsgcHJvY2Vzcy5leGl0KDEpOyB9CmZ1bmN0aW9uIHBhdGNoKHJlbCwgZWRpdHMpIHsKICBjb25zdCBmaWxlID0gcGF0aC5qb2luKFJPT1QsIHJlbCk7IGxldCBzID0gZnMucmVhZEZpbGVTeW5jKGZpbGUsICd1dGY4Jyk7CiAgZm9yIChjb25zdCBlIG9mIGVkaXRzKSB7CiAgICBpZiAocy5pbmRleE9mKGUuZ3VhcmQpID49IDApIHsgY29uc29sZS5sb2coJ3NraXAgKGFscmVhZHkpOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsgY29udGludWU7IH0KICAgIGNvbnN0IGZpcnN0ID0gcy5pbmRleE9mKGUuZmluZCk7CiAgICBpZiAoZmlyc3QgPCAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBNSVNTOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIGlmIChzLmluZGV4T2YoZS5maW5kLCBmaXJzdCArIDEpID49IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE5PVCBVTklRVUU6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgcyA9IHMuc2xpY2UoMCwgZmlyc3QpICsgZS5yZXBsYWNlICsgcy5zbGljZShmaXJzdCArIGUuZmluZC5sZW5ndGgpOwogICAgY29uc29sZS5sb2coJ3BhdGNoZWQ6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogIH0KICBmcy53cml0ZUZpbGVTeW5jKGZpbGUsIHMpOwp9CgpwYXRjaCgndmlld3MvcGFydGlhbHMvc3RvcmVfdG9wLmVqcycsIFsKICB7IG5hbWU6ICdjYXRkZC1ob3ZlcicsCiAgICBndWFyZDogJ0BtZWRpYShob3Zlcjpob3Zlcil7LmNhdGRkOmhvdmVyJywKICAgIGZpbmQ6ICcgIC5jYXRkZC1tZW51IGE6aG92ZXJ7YmFja2dyb3VuZDp2YXIoLS1iZzAsI2YzZjVmYil9XG48L3N0eWxlPicsCiAgICByZXBsYWNlOiAnICAuY2F0ZGQtbWVudSBhOmhvdmVye2JhY2tncm91bmQ6dmFyKC0tYmcwLCNmM2Y1ZmIpfVxuICBAbWVkaWEoaG92ZXI6aG92ZXIpey5jYXRkZDpob3ZlciAuY2F0ZGQtbWVudXtkaXNwbGF5OmJsb2NrfS5jYXRkZDpob3ZlciAuY2F0ZGQtYnRuIC5jeHt0cmFuc2Zvcm06cm90YXRlKDE4MGRlZyl9fVxuPC9zdHlsZT4nIH0KXSk7CgpwYXRjaCgndmlld3MvcGFydGlhbHMvc3RvcmVfYm90dG9tLmVqcycsIFsKICB7IG5hbWU6ICdtb2RhbC1ub3Njcm9sbGJhcicsCiAgICBndWFyZDogJ3Njcm9sbGJhci13aWR0aDpub25lJywKICAgIGZpbmQ6ICcudHJpYWxtLWxpc3R7ZGlzcGxheTpncmlkO2dhcDo4cHg7bWF4LWhlaWdodDo1MnZoO292ZXJmbG93LXk6YXV0bzstd2Via2l0LW92ZXJmbG93LXNjcm9sbGluZzp0b3VjaDttYXJnaW46MCAtNHB4O3BhZGRpbmc6MCA0cHh9JywKICAgIHJlcGxhY2U6ICcudHJpYWxtLWxpc3R7ZGlzcGxheTpncmlkO2dhcDo4cHg7bWF4LWhlaWdodDo1OHZoO292ZXJmbG93LXk6YXV0bzstd2Via2l0LW92ZXJmbG93LXNjcm9sbGluZzp0b3VjaDttYXJnaW46MCAtNHB4O3BhZGRpbmc6MCA0cHg7c2Nyb2xsYmFyLXdpZHRoOm5vbmV9XG4gIC50cmlhbG0tbGlzdDo6LXdlYmtpdC1zY3JvbGxiYXJ7ZGlzcGxheTpub25lfScgfQpdKTsKCmNvbnNvbGUubG9nKCdBTEwgUEFUQ0hFUyBBUFBMSUVEJyk7Cg==" | base64 -d > "$PATCHER"
echo "==> applying"; NODE_PATH="$GSZ/node_modules" node "$PATCHER" "$GSZ"
echo "==> validating"; for v in store_top.ejs store_bottom.ejs; do NODE_PATH="$GSZ/node_modules" node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/views/partials/'+'$v','utf8'),{filename:'$v'});"; done; echo "    ejs ok"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000; for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    homepage $CODE"; false; }
echo "    homepage 200: OK (after ${i}s)"
rm -f "$PATCHER"; trap - ERR
echo ""
echo "==> step169 OK  Browse opens on hover and click. Trials modal scrolls cleanly with no visible scrollbar. Hard-refresh once."
