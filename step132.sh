#!/usr/bin/env bash
# GSZ step132 — version-names (/admin/labels) now lists ALL IPTVs with a
# storefront plan mapped to a bot SKU, not only source='bot' plans (manually
# mapped IPTVs were hidden). One-line read-fix, no migration. Idempotent.
set -euo pipefail
GSZ=/opt/gsz; TS=$(date +%Y%m%d-%H%M%S); BK="$GSZ/.bak-step132-$TS"; TMP=$(mktemp -d)
FILES=(routes/adminLabels.js)
echo "==> step132: show all IPTVs in version names"
mkdir -p "$BK"; for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
echo "    backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTMyIHBhdGNoZXIg4oCUIHZlcnNpb24tbmFtZXMgKGxhYmVscykgcGFnZSBub3cgbGlzdHMgQUxMIElQVFZzIHRoYXQgaGF2ZSBhCiAgIHN0b3JlZnJvbnQgcGxhbiBtYXBwZWQgdG8gYSBib3QgU0tVLCBub3Qgb25seSBwbGFucyBjcmVhdGVkIHdpdGggc291cmNlPSdib3QnLgogICBNYW51YWxseS1tYXBwZWQgSVBUVnMgd2VyZSBiZWluZyBoaWRkZW4uIElkZW1wb3RlbnQ7IGFib3J0cyBvbiBiYWQgYW5jaG9yLiAqLwpjb25zdCBmcyA9IHJlcXVpcmUoJ2ZzJyk7IGNvbnN0IHBhdGggPSByZXF1aXJlKCdwYXRoJyk7CmNvbnN0IFJPT1QgPSBwcm9jZXNzLmFyZ3ZbMl07IGlmICghUk9PVCkgeyBjb25zb2xlLmVycm9yKCd1c2FnZTogcGF0Y2hfc3RlcDEzMi5qcyA8Z3N6LXJvb3Q+Jyk7IHByb2Nlc3MuZXhpdCgxKTsgfQpmdW5jdGlvbiBwYXRjaChyZWwsIGVkaXRzKSB7CiAgY29uc3QgZmlsZSA9IHBhdGguam9pbihST09ULCByZWwpOyBsZXQgcyA9IGZzLnJlYWRGaWxlU3luYyhmaWxlLCAndXRmOCcpOwogIGZvciAoY29uc3QgZSBvZiBlZGl0cykgewogICAgaWYgKHMuaW5kZXhPZihlLmd1YXJkKSA+PSAwKSB7IGNvbnNvbGUubG9nKCdza2lwIChhbHJlYWR5KTogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7IGNvbnRpbnVlOyB9CiAgICBjb25zdCBmaXJzdCA9IHMuaW5kZXhPZihlLmZpbmQpOwogICAgaWYgKGZpcnN0IDwgMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTUlTUzogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgICBpZiAocy5pbmRleE9mKGUuZmluZCwgZmlyc3QgKyAxKSA+PSAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBOT1QgVU5JUVVFOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIHMgPSBzLnNsaWNlKDAsIGZpcnN0KSArIGUucmVwbGFjZSArIHMuc2xpY2UoZmlyc3QgKyBlLmZpbmQubGVuZ3RoKTsKICAgIGNvbnNvbGUubG9nKCdwYXRjaGVkOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICB9CiAgZnMud3JpdGVGaWxlU3luYyhmaWxlLCBzKTsKfQpwYXRjaCgncm91dGVzL2FkbWluTGFiZWxzLmpzJywgWwogIHsgbmFtZTogJ2xhYmVscy1zaG93LWFsbC1tYXBwZWQnLAogICAgZ3VhcmQ6ICJTRUxFQ1QgRElTVElOQ1QgYm90X3NrdSBGUk9NIHByb2R1Y3RfcGxhbnMgV0hFUkUgYm90X3NrdSBJUyBOT1QgTlVMTCIsCiAgICBmaW5kOiAiU0VMRUNUIERJU1RJTkNUIGJvdF9za3UgRlJPTSBwcm9kdWN0X3BsYW5zIFdIRVJFIHNvdXJjZT0nYm90JyBBTkQgYm90X3NrdSBJUyBOT1QgTlVMTCIsCiAgICByZXBsYWNlOiAiU0VMRUNUIERJU1RJTkNUIGJvdF9za3UgRlJPTSBwcm9kdWN0X3BsYW5zIFdIRVJFIGJvdF9za3UgSVMgTk9UIE5VTEwiIH0KXSk7CmNvbnNvbGUubG9nKCdBTEwgUEFUQ0hFUyBBUFBMSUVEJyk7Cg==" | base64 -d > "$TMP/p.js"
echo "==> applying"; node "$TMP/p.js" "$GSZ"
echo "==> validating"; node --check "$GSZ/routes/adminLabels.js"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz; sleep 2
CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$CODE" = "200" ] && echo "    homepage 200: OK" || { echo "    homepage $CODE"; false; }
trap - ERR; rm -rf "$TMP"
echo ""; echo "==> step132 OK ✅  /admin/labels (Version names) now shows every IPTV that has a storefront plan, regardless of how it was mapped."
