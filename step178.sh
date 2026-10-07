#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
F="$GSZ/views/admin/_shell_top.ejs"
TS=$(date +%Y%m%d-%H%M%S); BK="$F.bak-step178-$TS"
echo "==> step178: admin top bar fits on phones (title ellipsis + tighter bar < 560px)"
cp "$F" "$BK"; echo "    backup: $BK"
restore(){ echo "!! restoring"; cp "$BK" "$F" 2>/dev/null||true; }
trap 'restore' ERR
PATCHER=$(mktemp /tmp/patch_step178.XXXXXX.js)
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTc4IOKAlCBhZG1pbiB0b3AgYmFyIG92ZXJmbG93ZWQgb24gcGhvbmVzOiB0aGUgc3RpY2t5IC50YmFyIGlzIGEgbm93cmFwIGZsZXggcm93CiAgIChoYW1idXJnZXIgcGFkICsgcGFnZSB0aXRsZSArICJWaWV3IHNpdGUiICsgIkxvZyBvdXQiKSB0aGF0IGV4Y2VlZHMgMzc1cHgsIHB1c2hpbmcKICAgIkxvZyBvdXQiIG9mZiB0aGUgcmlnaHQgZWRnZS4gTWFrZSB0aGUgdGl0bGUgZmxleC9lbGxpcHNpcyBhbmQgdGlnaHRlbiB0aGUgYmFyIGJlbG93CiAgIDU2MHB4IHNvIGV2ZXJ5dGhpbmcgZml0cy4gU2hhcmVkIGFkbWluIHNoZWxsIOKGkiBmaXhlcyBldmVyeSBhZG1pbiBwYWdlLiBJZGVtcG90ZW50LiAqLwpjb25zdCBmcyA9IHJlcXVpcmUoJ2ZzJyk7IGNvbnN0IHBhdGggPSByZXF1aXJlKCdwYXRoJyk7CmNvbnN0IFJPT1QgPSBwcm9jZXNzLmFyZ3ZbMl07IGlmICghUk9PVCkgeyBjb25zb2xlLmVycm9yKCd1c2FnZScpOyBwcm9jZXNzLmV4aXQoMSk7IH0KY29uc3QgcmVsID0gJ3ZpZXdzL2FkbWluL19zaGVsbF90b3AuZWpzJzsKY29uc3QgZmlsZSA9IHBhdGguam9pbihST09ULCByZWwpOwpsZXQgcyA9IGZzLnJlYWRGaWxlU3luYyhmaWxlLCAndXRmOCcpOwoKaWYgKHMuaW5kZXhPZignLnRiYXIgaDF7ZmxleDoxJykgPj0gMCkgeyBjb25zb2xlLmxvZygnc2tpcCAoYWxyZWFkeSk6IGFkbWluIHRiYXIgcGhvbmUgZml4Jyk7IGNvbnNvbGUubG9nKCdBTEwgUEFUQ0hFUyBBUFBMSUVEJyk7IHByb2Nlc3MuZXhpdCgwKTsgfQoKY29uc3QgRklORCA9ICcudGJhcntkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMnB4O3BhZGRpbmc6MCAyOHB4O2hlaWdodDo2OHB4O2JhY2tncm91bmQ6cmdiYSgyNDQsMjQ2LDI1MiwuODUpO2JhY2tkcm9wLWZpbHRlcjpibHVyKDEwcHgpO3Bvc2l0aW9uOnN0aWNreTt0b3A6MDt6LWluZGV4OjIwO2JvcmRlci1ib3R0b206MXB4IHNvbGlkIHZhcigtLWhhaXIpfSc7CmNvbnN0IEFERCA9CidcbiAgQG1lZGlhKG1heC13aWR0aDo1NjBweCl7XG4nICsKJyAgICAudGJhcntnYXA6OHB4O3BhZGRpbmctbGVmdDo2MHB4O3BhZGRpbmctcmlnaHQ6MTRweH1cbicgKwonICAgIC50YmFyIGgxe2ZsZXg6MTttaW4td2lkdGg6MDt3aGl0ZS1zcGFjZTpub3dyYXA7b3ZlcmZsb3c6aGlkZGVuO3RleHQtb3ZlcmZsb3c6ZWxsaXBzaXM7Zm9udC1zaXplOjE4cHh9XG4nICsKJyAgICAudGJhciAuYnRue3BhZGRpbmc6N3B4IDEwcHg7Zm9udC1zaXplOjEyLjVweH1cbicgKwonICB9JzsKCmNvbnN0IGkgPSBzLmluZGV4T2YoRklORCk7CmlmIChpIDwgMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTUlTUzogLnRiYXIgYmFzZSBydWxlIGluICcgKyByZWwpOwppZiAocy5pbmRleE9mKEZJTkQsIGkgKyAxKSA+PSAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBOT1QgVU5JUVVFOiAudGJhciBiYXNlIHJ1bGUgaW4gJyArIHJlbCk7CnMgPSBzLnNsaWNlKDAsIGkgKyBGSU5ELmxlbmd0aCkgKyBBREQgKyBzLnNsaWNlKGkgKyBGSU5ELmxlbmd0aCk7CmZzLndyaXRlRmlsZVN5bmMoZmlsZSwgcyk7CmNvbnNvbGUubG9nKCdwYXRjaGVkOiAnICsgcmVsICsgJyA6OiBhZG1pbiB0YmFyIHBob25lIGZpeCcpOwpjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOwo=" | base64 -d > "$PATCHER"
echo "==> applying"; NODE_PATH="$GSZ/node_modules" node "$PATCHER" "$GSZ"
echo "==> validating"; NODE_PATH="$GSZ/node_modules" node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$F','utf8'),{filename:'$F'});console.log('    ejs ok')"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000; for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/admin/login || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    admin $CODE"; false; }
echo "    admin up: OK (after ${i}s)"
rm -f "$PATCHER"; trap - ERR
echo ""
echo "==> step178 OK  Admin top bar no longer overflows on phones (page title truncates, Log out stays on screen)."
