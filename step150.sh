#!/usr/bin/env bash
# GSZ step150 — show live stock for PORTAL products on the storefront (calls the
# bot's stock API for portal SKUs too, not just 'stock' types). Patches
# routes/products.js. No migration. Idempotent; robust health check.
set -euo pipefail
GSZ=/opt/gsz; TS=$(date +%Y%m%d-%H%M%S); BK="$GSZ/.bak-step150-$TS"; TMP=$(mktemp -d)
FILES=(routes/products.js)
echo "==> step150: portal live stock on storefront"
mkdir -p "$BK/routes"; for f in "${FILES[@]}"; do cp "$GSZ/$f" "$BK/$f"; done
echo "    backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTUwIHBhdGNoZXIg4oCUIHNob3cgbGl2ZSBzdG9jayBmb3IgUE9SVEFMIHByb2R1Y3RzIG9uIHRoZSBzdG9yZWZyb250IHRvbwogICAobm90IGp1c3QgJ3N0b2NrJyBib3QgcHJvZHVjdHMpLiBDYWxscyBib3RhcGkuZ2V0U3RvY2sgZm9yIHBvcnRhbCBTS1VzIGFzIHdlbGwuCiAgIElkZW1wb3RlbnQuICovCmNvbnN0IGZzID0gcmVxdWlyZSgnZnMnKTsgY29uc3QgcGF0aCA9IHJlcXVpcmUoJ3BhdGgnKTsKY29uc3QgUk9PVCA9IHByb2Nlc3MuYXJndlsyXTsgaWYgKCFST09UKSB7IGNvbnNvbGUuZXJyb3IoJ3VzYWdlJyk7IHByb2Nlc3MuZXhpdCgxKTsgfQpmdW5jdGlvbiBwYXRjaChyZWwsIGVkaXRzKSB7CiAgY29uc3QgZmlsZSA9IHBhdGguam9pbihST09ULCByZWwpOyBsZXQgcyA9IGZzLnJlYWRGaWxlU3luYyhmaWxlLCAndXRmOCcpOwogIGZvciAoY29uc3QgZSBvZiBlZGl0cykgewogICAgaWYgKHMuaW5kZXhPZihlLmd1YXJkKSA+PSAwKSB7IGNvbnNvbGUubG9nKCdza2lwIChhbHJlYWR5KTogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7IGNvbnRpbnVlOyB9CiAgICBjb25zdCBmaXJzdCA9IHMuaW5kZXhPZihlLmZpbmQpOwogICAgaWYgKGZpcnN0IDwgMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTUlTUzogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgICBpZiAocy5pbmRleE9mKGUuZmluZCwgZmlyc3QgKyAxKSA+PSAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBOT1QgVU5JUVVFOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIHMgPSBzLnNsaWNlKDAsIGZpcnN0KSArIGUucmVwbGFjZSArIHMuc2xpY2UoZmlyc3QgKyBlLmZpbmQubGVuZ3RoKTsKICAgIGNvbnNvbGUubG9nKCdwYXRjaGVkOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICB9CiAgZnMud3JpdGVGaWxlU3luYyhmaWxlLCBzKTsKfQpjb25zdCBGID0gIn0gZWxzZSBpZiAoci5zb3VyY2UgPT09ICdib3QnICYmIHIuYm90X3NrdSAmJiBib3REZWxpdmVyeVtyLmJvdF9za3VdID09PSAnc3RvY2snICYmIGJvdGFwaS5jb25maWd1cmVkKCkpIHsiOwpjb25zdCBSID0gIn0gZWxzZSBpZiAoci5zb3VyY2UgPT09ICdib3QnICYmIHIuYm90X3NrdSAmJiBbJ3N0b2NrJywgJ3BvcnRhbCddLmluZGV4T2YoYm90RGVsaXZlcnlbci5ib3Rfc2t1XSkgPj0gMCAmJiBib3RhcGkuY29uZmlndXJlZCgpKSB7IjsKcGF0Y2goJ3JvdXRlcy9wcm9kdWN0cy5qcycsIFsKICB7IG5hbWU6ICdwb3J0YWwtbGl2ZS1zdG9jaycsIGd1YXJkOiAiWydzdG9jaycsICdwb3J0YWwnXS5pbmRleE9mKGJvdERlbGl2ZXJ5IiwgZmluZDogRiwgcmVwbGFjZTogUiB9Cl0pOwpjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOwo=" | base64 -d > "$TMP/p.js"
echo "==> applying"; node "$TMP/p.js" "$GSZ"
echo "==> validating"; node --check "$GSZ/routes/products.js"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000; for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] && echo "    homepage 200: OK (after ${i}s)" || { echo "    homepage $CODE"; false; }
trap - ERR; rm -rf "$TMP"
echo ""; echo "==> step150 OK ✅  Portal products now request live stock on the storefront. If a portal product STILL shows no count, the reseller bot's /api/stock isn't returning portal stock for that SKU — tell me and I'll give you the bot-side snippet."
