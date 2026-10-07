#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
F="$GSZ/views/partials/store_top.ejs"
TS=$(date +%Y%m%d-%H%M%S); BK="$F.bak-step181-$TS"
echo "==> step181: site-wide premium finish (smooth scroll, focus rings, selection, press feedback)"
cp "$F" "$BK"; echo "    backup: $BK"
restore(){ echo "!! restoring"; cp "$BK" "$F" 2>/dev/null||true; }
trap 'restore' ERR
P=$(mktemp /tmp/p181.XXXXXX.js); echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTgxIOKAlCBzaXRlLXdpZGUgcHJlbWl1bSBmaW5pc2ggKGFkZGl0aXZlLCBubyBvdmVycmlkZXMsIG5vICFpbXBvcnRhbnQpLiBBZGRzIGEKICAgc21hbGwgcG9saXNoIGxheWVyIHRvIHRoZSBzaGFyZWQgaGVhZGVyIHN0eWxlOiBzbW9vdGggc2Nyb2xsaW5nLCBicmFuZGVkIHNlbGVjdGlvbiwKICAgYWNjZXNzaWJsZSBrZXlib2FyZCBmb2N1cyByaW5ncywgYW5kIHJlZHVjZWQtbW90aW9uIHJlc3BlY3QuIEFwcGxpZXMgb24gZXZlcnkgcGFnZQogICB0aGF0IHVzZXMgdGhlIHN0b3JlIGhlYWRlci4gSWRlbXBvdGVudC4gKi8KY29uc3QgZnMgPSByZXF1aXJlKCdmcycpOyBjb25zdCBwYXRoID0gcmVxdWlyZSgncGF0aCcpOwpjb25zdCBST09UID0gcHJvY2Vzcy5hcmd2WzJdOyBpZiAoIVJPT1QpIHsgY29uc29sZS5lcnJvcigndXNhZ2UnKTsgcHJvY2Vzcy5leGl0KDEpOyB9CmNvbnN0IHJlbCA9ICd2aWV3cy9wYXJ0aWFscy9zdG9yZV90b3AuZWpzJzsKY29uc3QgZmlsZSA9IHBhdGguam9pbihST09ULCByZWwpOwpsZXQgcyA9IGZzLnJlYWRGaWxlU3luYyhmaWxlLCAndXRmOCcpOwppZiAocy5pbmRleE9mKCcvKnByZW1pdW1Qb2xpc2gqLycpID49IDApIHsgY29uc29sZS5sb2coJ3NraXAgKGFscmVhZHkpOiBwcmVtaXVtIHBvbGlzaCcpOyBjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOyBwcm9jZXNzLmV4aXQoMCk7IH0KCmNvbnN0IFBPTElTSCA9Cic8c3R5bGU+LypwcmVtaXVtUG9saXNoKi9cbicgKwonICBodG1se3Njcm9sbC1iZWhhdmlvcjpzbW9vdGh9XG4nICsKJyAgQG1lZGlhKHByZWZlcnMtcmVkdWNlZC1tb3Rpb246cmVkdWNlKXtodG1se3Njcm9sbC1iZWhhdmlvcjphdXRvfX1cbicgKwonICA6OnNlbGVjdGlvbntiYWNrZ3JvdW5kOnJnYmEoNDIsMTIzLDI1NSwuMTgpO2NvbG9yOmluaGVyaXR9XG4nICsKJyAgYTpmb2N1cy12aXNpYmxlLGJ1dHRvbjpmb2N1cy12aXNpYmxlLFt0YWJpbmRleF06Zm9jdXMtdmlzaWJsZSxpbnB1dDpmb2N1cy12aXNpYmxlLHNlbGVjdDpmb2N1cy12aXNpYmxlLHRleHRhcmVhOmZvY3VzLXZpc2libGV7b3V0bGluZToycHggc29saWQgdmFyKC0tYnJhbmQsIzJhNmNmZik7b3V0bGluZS1vZmZzZXQ6MnB4O2JvcmRlci1yYWRpdXM6NnB4fVxuJyArCicgIC5idG4sYS5idG57dHJhbnNpdGlvbjp0cmFuc2Zvcm0gLjE1cyBlYXNlLGJveC1zaGFkb3cgLjJzIGVhc2UsZmlsdGVyIC4ycyBlYXNlfVxuJyArCicgIC5idG46YWN0aXZlLGEuYnRuOmFjdGl2ZXt0cmFuc2Zvcm06dHJhbnNsYXRlWSgxcHgpfVxuJyArCic8L3N0eWxlPlxuJzsKCmNvbnN0IEZJTkQgPSAnPHN0eWxlPi8qY2F0ZGRDc3MqLyc7CmNvbnN0IGkgPSBzLmluZGV4T2YoRklORCk7CmlmIChpIDwgMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTUlTUzogY2F0ZGRDc3Mgc3R5bGUgaW4gJyArIHJlbCk7CmlmIChzLmluZGV4T2YoRklORCwgaSArIDEpID49IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE5PVCBVTklRVUU6IGNhdGRkQ3NzIHN0eWxlIGluICcgKyByZWwpOwpzID0gcy5zbGljZSgwLCBpKSArIFBPTElTSCArIHMuc2xpY2UoaSk7CmZzLndyaXRlRmlsZVN5bmMoZmlsZSwgcyk7CmNvbnNvbGUubG9nKCdwYXRjaGVkOiAnICsgcmVsICsgJyA6OiBwcmVtaXVtIHBvbGlzaCcpOwpjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOwo=" | base64 -d > "$P"
echo "==> applying"; NODE_PATH="$GSZ/node_modules" node "$P" "$GSZ"
echo "==> validating"; NODE_PATH="$GSZ/node_modules" node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$F','utf8'),{filename:'$F'});console.log('    ejs ok')"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000; for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    homepage $CODE"; false; }
echo "    homepage 200: OK (after ${i}s)"
rm -f "$P"; trap - ERR
echo "==> step181 OK  Global premium finish applied. Just reload."
