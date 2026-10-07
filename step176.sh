#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
F="$GSZ/views/admin/_shell_bottom.ejs"
TS=$(date +%Y%m%d-%H%M%S); BK="$F.bak-step176-$TS"
echo "==> step176: admin pages keep scroll position (no more jump-to-top on actions)"
cp "$F" "$BK"; echo "    backup: $BK"
restore(){ echo "!! restoring"; cp "$BK" "$F" 2>/dev/null||true; }
trap 'restore' ERR
PATCHER=$(mktemp /tmp/patch_step176.XXXXXX.js)
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTc2IOKAlCBhZG1pbiBkYXNoYm9hcmQvcGFnZXMganVtcCB0byB0b3AgYWZ0ZXIgYW4gYWN0aW9uIG9yIHJlZnJlc2guIEFkZCBhIHRpbnkKICAgc2Nyb2xsLXBvc2l0aW9uIGtlZXBlciB0byB0aGUgc2hhcmVkIGFkbWluIHNoZWxsIGZvb3RlciAoX3NoZWxsX2JvdHRvbS5lanMpOiBpdCBzYXZlcwogICBzY3JvbGxZIChrZXllZCBwZXIgcGF0aCkgb24gZm9ybSBzdWJtaXQgLyB1bmxvYWQgYW5kIHJlc3RvcmVzIGl0IG9uIHRoZSBuZXh0IGxvYWQgb2YKICAgdGhlIHNhbWUgcGFnZSwgc28gYWN0aW9ucyBubyBsb25nZXIgYm91bmNlIHlvdSB0byB0aGUgdG9wLiBJZGVtcG90ZW50LiAqLwpjb25zdCBmcyA9IHJlcXVpcmUoJ2ZzJyk7IGNvbnN0IHBhdGggPSByZXF1aXJlKCdwYXRoJyk7CmNvbnN0IFJPT1QgPSBwcm9jZXNzLmFyZ3ZbMl07IGlmICghUk9PVCkgeyBjb25zb2xlLmVycm9yKCd1c2FnZScpOyBwcm9jZXNzLmV4aXQoMSk7IH0KY29uc3QgcmVsID0gJ3ZpZXdzL2FkbWluL19zaGVsbF9ib3R0b20uZWpzJzsKY29uc3QgZmlsZSA9IHBhdGguam9pbihST09ULCByZWwpOwpsZXQgcyA9IGZzLnJlYWRGaWxlU3luYyhmaWxlLCAndXRmOCcpOwoKaWYgKHMuaW5kZXhPZignZ3N6X2FkbV9zY3JvbGwnKSA+PSAwKSB7IGNvbnNvbGUubG9nKCdza2lwIChhbHJlYWR5KTogYWRtaW4gc2Nyb2xsIGtlZXBlcicpOyBjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOyBwcm9jZXNzLmV4aXQoMCk7IH0KCmNvbnN0IFNDUklQVCA9Cic8c2NyaXB0Pi8qZ3N6X2FkbV9zY3JvbGwqLyhmdW5jdGlvbigpe1xuJyArCicgIHRyeXsgaWYoInNjcm9sbFJlc3RvcmF0aW9uIiBpbiBoaXN0b3J5KSBoaXN0b3J5LnNjcm9sbFJlc3RvcmF0aW9uPSJtYW51YWwiOyB9Y2F0Y2goZSl7fVxuJyArCicgIHZhciBLRVk9Imdzel9hZG1fc2Nyb2xsOiIrbG9jYXRpb24ucGF0aG5hbWU7XG4nICsKJyAgZnVuY3Rpb24gcmVzdG9yZSgpeyB0cnl7IHZhciB5PXNlc3Npb25TdG9yYWdlLmdldEl0ZW0oS0VZKTsgaWYoeSE9PW51bGwpIHdpbmRvdy5zY3JvbGxUbygwLCBwYXJzZUludCh5LDEwKXx8MCk7IH1jYXRjaChlKXt9IH1cbicgKwonICBmdW5jdGlvbiBzYXZlKCl7IHRyeXsgc2Vzc2lvblN0b3JhZ2Uuc2V0SXRlbShLRVksIFN0cmluZyh3aW5kb3cuc2Nyb2xsWXx8d2luZG93LnBhZ2VZT2Zmc2V0fHwwKSk7IH1jYXRjaChlKXt9IH1cbicgKwonICBkb2N1bWVudC5hZGRFdmVudExpc3RlbmVyKCJzdWJtaXQiLCBzYXZlLCB0cnVlKTtcbicgKwonICB3aW5kb3cuYWRkRXZlbnRMaXN0ZW5lcigiYmVmb3JldW5sb2FkIiwgc2F2ZSk7XG4nICsKJyAgcmVzdG9yZSgpO1xuJyArCicgIHdpbmRvdy5hZGRFdmVudExpc3RlbmVyKCJsb2FkIiwgZnVuY3Rpb24oKXsgcmVzdG9yZSgpOyB0cnl7IHNlc3Npb25TdG9yYWdlLnJlbW92ZUl0ZW0oS0VZKTsgfWNhdGNoKGUpe30gfSk7XG4nICsKJ30pKCk7PC9zY3JpcHQ+XG4nOwoKY29uc3QgQU5DSE9SID0gJzwvYm9keT48L2h0bWw+JzsKY29uc3QgaSA9IHMuaW5kZXhPZihBTkNIT1IpOwppZiAoaSA8IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE1JU1M6IDwvYm9keT48L2h0bWw+IGluICcgKyByZWwpOwppZiAocy5pbmRleE9mKEFOQ0hPUiwgaSArIDEpID49IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE5PVCBVTklRVUU6IDwvYm9keT48L2h0bWw+IGluICcgKyByZWwpOwpzID0gcy5zbGljZSgwLCBpKSArIFNDUklQVCArIHMuc2xpY2UoaSk7CmZzLndyaXRlRmlsZVN5bmMoZmlsZSwgcyk7CmNvbnNvbGUubG9nKCdwYXRjaGVkOiAnICsgcmVsICsgJyA6OiBhZG1pbiBzY3JvbGwga2VlcGVyJyk7CmNvbnNvbGUubG9nKCdBTEwgUEFUQ0hFUyBBUFBMSUVEJyk7Cg==" | base64 -d > "$PATCHER"
echo "==> applying"; NODE_PATH="$GSZ/node_modules" node "$PATCHER" "$GSZ"
echo "==> validating"; NODE_PATH="$GSZ/node_modules" node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$F','utf8'),{filename:'$F'});console.log('    ejs ok')"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000; for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    admin $CODE"; false; }
echo "    admin up: OK (after ${i}s)"
rm -f "$PATCHER"; trap - ERR
echo ""
echo "==> step176 OK  Admin pages now restore your scroll position after a save/action/refresh instead of jumping to the top."
