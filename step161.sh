#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/routes/trials.js.bak-step161-$TS"
echo "==> step161: free IPTV trial requires WhatsApp (not email) (#1)"
[ -f "$GSZ/routes/trials.js" ] || { echo "!! trials.js not found"; exit 1; }
cp "$GSZ/routes/trials.js" "$BK"; echo "    backup: $BK"
restore(){ echo "!! error — restoring"; cp "$BK" "$GSZ/routes/trials.js" 2>/dev/null || true; }
trap 'restore' ERR
PATCHER=$(mktemp /tmp/patch_step161.XXXXXX.js)
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTYxIOKAlCAjMSBGcmVlIElQVFYgdHJpYWwgbXVzdCBub3QgYXNrIGZvciBFTUFJTCB2ZXJpZmljYXRpb24uIFRoZSB0cmlhbCBpcwogICBnYXRlZCBhbmQgcXVvdGEtdHJhY2tlZCBvbiB0aGUgV2hhdHNBcHAgaWRlbnRpdHksIHNvIHJlcXVpcmUgV2hhdHNBcHAgKG5vdCBlbWFpbCkKICAgdmVyaWZpY2F0aW9uOyB1bnZlcmlmaWVkIOKGkiB0aGUgV2hhdHNBcHAgdmVyaWZ5IHBhZ2UuIElkZW1wb3RlbnQuICovCmNvbnN0IGZzID0gcmVxdWlyZSgnZnMnKTsgY29uc3QgcGF0aCA9IHJlcXVpcmUoJ3BhdGgnKTsKY29uc3QgUk9PVCA9IHByb2Nlc3MuYXJndlsyXTsgaWYgKCFST09UKSB7IGNvbnNvbGUuZXJyb3IoJ3VzYWdlJyk7IHByb2Nlc3MuZXhpdCgxKTsgfQpmdW5jdGlvbiBwYXRjaChyZWwsIGVkaXRzKSB7CiAgY29uc3QgZmlsZSA9IHBhdGguam9pbihST09ULCByZWwpOyBsZXQgcyA9IGZzLnJlYWRGaWxlU3luYyhmaWxlLCAndXRmOCcpOwogIGZvciAoY29uc3QgZSBvZiBlZGl0cykgewogICAgaWYgKHMuaW5kZXhPZihlLmd1YXJkKSA+PSAwKSB7IGNvbnNvbGUubG9nKCdza2lwIChhbHJlYWR5KTogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7IGNvbnRpbnVlOyB9CiAgICBjb25zdCBmaXJzdCA9IHMuaW5kZXhPZihlLmZpbmQpOwogICAgaWYgKGZpcnN0IDwgMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTUlTUzogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgICBpZiAocy5pbmRleE9mKGUuZmluZCwgZmlyc3QgKyAxKSA+PSAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBOT1QgVU5JUVVFOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIHMgPSBzLnNsaWNlKDAsIGZpcnN0KSArIGUucmVwbGFjZSArIHMuc2xpY2UoZmlyc3QgKyBlLmZpbmQubGVuZ3RoKTsKICAgIGNvbnNvbGUubG9nKCdwYXRjaGVkOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICB9CiAgZnMud3JpdGVGaWxlU3luYyhmaWxlLCBzKTsKfQpwYXRjaCgncm91dGVzL3RyaWFscy5qcycsIFsKICB7IG5hbWU6ICd0cmlhbC13YS1nYXRlJywKICAgIGd1YXJkOiAiaWYgKCF2LndhT2spIHJldHVybiByZXMucmVkaXJlY3QoJy9hY2NvdW50L3doYXRzYXBwJykiLAogICAgZmluZDogImlmICghdi5lbWFpbE9rKSByZXR1cm4gcmVzLnJlZGlyZWN0KCcvYWNjb3VudC92ZXJpZnktZW1haWwnKTsiLAogICAgcmVwbGFjZTogImlmICghdi53YU9rKSByZXR1cm4gcmVzLnJlZGlyZWN0KCcvYWNjb3VudC93aGF0c2FwcCcpOyIgfQpdKTsKY29uc29sZS5sb2coJ0FMTCBQQVRDSEVTIEFQUExJRUQnKTsK" | base64 -d > "$PATCHER"
echo "==> applying"
NODE_PATH="$GSZ/node_modules" node "$PATCHER" "$GSZ"
echo "==> validating"
node --check "$GSZ/routes/trials.js" && echo "    node --check ok"
echo "==> restarting"
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000
for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    homepage $CODE after ${i}s"; false; }
echo "    homepage 200: OK (after ${i}s)"
rm -f "$PATCHER"
trap - ERR
echo ""
echo "==> step161 OK  Claiming a free IPTV trial now only needs WhatsApp verification — no email step. Unverified customers are sent to verify WhatsApp (which the trial needs anyway for delivery + quota)."
