#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
F="$GSZ/views/partials/store_top.ejs"
TS=$(date +%Y%m%d-%H%M%S); BK="$F.bak-step175-$TS"
echo "==> step175: Browse hover gap — real fix (bridge on .catdd, not the clipped menu)"
cp "$F" "$BK"; echo "    backup: $BK"
restore(){ echo "!! restoring"; cp "$BK" "$F" 2>/dev/null||true; }
trap 'restore' ERR
PATCHER=$(mktemp /tmp/patch_step175.XXXXXX.js)
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTc1IOKAlCBmaXggdGhlIEJyb3dzZSBob3ZlciBnYXAgZm9yIHJlYWwuIFRoZSBzdGVwMTc0IGJyaWRnZSB3YXMgYSA6OmJlZm9yZSBvbgogICAuY2F0ZGQtbWVudSwgYnV0IHRoZSBtZW51IGhhcyBvdmVyZmxvdzphdXRvLCB3aGljaCBDTElQUyBhbnkgY2hpbGQgcGxhY2VkIGFib3ZlIGl0IOKAlAogICBzbyB0aGUgYnJpZGdlIGhhZCBubyBhcmVhLiBNb3ZlIHRoZSBicmlkZ2Ugb250byAuY2F0ZGQgaXRzZWxmIChwb3NpdGlvbjpyZWxhdGl2ZSwgbm8KICAgY2xpcCkgYXMgYSA6aG92ZXI6OmFmdGVyIHN0cmlwIHNwYW5uaW5nIHRoZSAxMnB4IGdhcCwgYW5kIHJlbW92ZSB0aGUgZGVhZCA6OmJlZm9yZS4KICAgSWRlbXBvdGVudC4gKi8KY29uc3QgZnMgPSByZXF1aXJlKCdmcycpOyBjb25zdCBwYXRoID0gcmVxdWlyZSgncGF0aCcpOwpjb25zdCBST09UID0gcHJvY2Vzcy5hcmd2WzJdOyBpZiAoIVJPT1QpIHsgY29uc29sZS5lcnJvcigndXNhZ2UnKTsgcHJvY2Vzcy5leGl0KDEpOyB9CmNvbnN0IHJlbCA9ICd2aWV3cy9wYXJ0aWFscy9zdG9yZV90b3AuZWpzJzsKY29uc3QgZmlsZSA9IHBhdGguam9pbihST09ULCByZWwpOwpsZXQgcyA9IGZzLnJlYWRGaWxlU3luYyhmaWxlLCAndXRmOCcpOwoKaWYgKHMuaW5kZXhPZignLmNhdGRkOmhvdmVyOjphZnRlcicpID49IDApIHsKICBjb25zb2xlLmxvZygnc2tpcCAoYWxyZWFkeSk6IGNhdGRkIGhvdmVyIGJyaWRnZSB2aWEgOjphZnRlcicpOwp9IGVsc2UgewogIC8vIDEpIHJlbW92ZSB0aGUgZGVhZCAoY2xpcHBlZCkgOjpiZWZvcmUgYnJpZGdlIGxpbmUsIGlmIHByZXNlbnQKICBjb25zdCBERUFEID0gJ1xuICAuY2F0ZGQtbWVudTo6YmVmb3Jle2NvbnRlbnQ6IiI7cG9zaXRpb246YWJzb2x1dGU7bGVmdDowO3JpZ2h0OjA7dG9wOi0xNHB4O2hlaWdodDoxNHB4fSc7CiAgaWYgKHMuaW5kZXhPZihERUFEKSA+PSAwKSB7IHMgPSBzLnJlcGxhY2UoREVBRCwgJycpOyBjb25zb2xlLmxvZygncmVtb3ZlZCBkZWFkIDo6YmVmb3JlIGJyaWRnZScpOyB9CiAgZWxzZSB7IGNvbnNvbGUubG9nKCdub3RlOiBkZWFkIDo6YmVmb3JlIG5vdCBmb3VuZCAob2spJyk7IH0KCiAgLy8gMikgYWRkIHRoZSByZWFsIGJyaWRnZSBpbnRvIHRoZSBob3ZlciBtZWRpYSBxdWVyeQogIGNvbnN0IEhPVkVSX0ZJTkQgPSAnQG1lZGlhKGhvdmVyOmhvdmVyKXsuY2F0ZGQ6aG92ZXIgLmNhdGRkLW1lbnV7ZGlzcGxheTpibG9ja30uY2F0ZGQ6aG92ZXIgLmNhdGRkLWJ0biAuY3h7dHJhbnNmb3JtOnJvdGF0ZSgxODBkZWcpfX0nOwogIGlmIChzLmluZGV4T2YoSE9WRVJfRklORCkgPCAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBNSVNTOiBob3ZlciBtZWRpYSBxdWVyeScpOwogIGlmIChzLmluZGV4T2YoSE9WRVJfRklORCwgcy5pbmRleE9mKEhPVkVSX0ZJTkQpICsgMSkgPj0gMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTk9UIFVOSVFVRTogaG92ZXIgbWVkaWEgcXVlcnknKTsKICBjb25zdCBIT1ZFUl9SRVBMID0gJ0BtZWRpYShob3Zlcjpob3Zlcil7LmNhdGRkOmhvdmVyIC5jYXRkZC1tZW51e2Rpc3BsYXk6YmxvY2t9LmNhdGRkOmhvdmVyIC5jYXRkZC1idG4gLmN4e3RyYW5zZm9ybTpyb3RhdGUoMTgwZGVnKX0uY2F0ZGQ6aG92ZXI6OmFmdGVye2NvbnRlbnQ6IiI7cG9zaXRpb246YWJzb2x1dGU7bGVmdDowO3RvcDoxMDAlO3dpZHRoOjIzMHB4O21heC13aWR0aDo2MHZ3O2hlaWdodDoxNHB4fX0nOwogIHMgPSBzLnJlcGxhY2UoSE9WRVJfRklORCwgSE9WRVJfUkVQTCk7CiAgY29uc29sZS5sb2coJ2FkZGVkIC5jYXRkZDpob3Zlcjo6YWZ0ZXIgYnJpZGdlJyk7CiAgZnMud3JpdGVGaWxlU3luYyhmaWxlLCBzKTsKfQpjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOwo=" | base64 -d > "$PATCHER"
echo "==> applying"; NODE_PATH="$GSZ/node_modules" node "$PATCHER" "$GSZ"
echo "==> validating"; NODE_PATH="$GSZ/node_modules" node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$F','utf8'),{filename:'$F'});console.log('    ejs ok')"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000; for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    homepage $CODE"; false; }
echo "    homepage 200: OK (after ${i}s)"
rm -f "$PATCHER"; trap - ERR
echo ""
echo "==> step175 OK  Browse now holds open when you move down into the categories. Reload."
