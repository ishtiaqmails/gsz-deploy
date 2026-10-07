#!/usr/bin/env bash
# GSZ step140 — show Binance / crypto at checkout in every region. Bot pay-accounts
# are region-filtered; a global-scoped Binance was hidden for PK visitors. This
# always includes crypto (USDT / binance / usdt / crypto) while keeping region
# filtering for fiat methods. One route patch, no migration. Idempotent.
set -euo pipefail
GSZ=/opt/gsz; TS=$(date +%Y%m%d-%H%M%S); BK="$GSZ/.bak-step140-$TS"; TMP=$(mktemp -d)
FILES=(routes/checkout.js)
echo "==> step140: Binance/crypto visible at checkout in all regions"
mkdir -p "$BK"; for f in "${FILES[@]}"; do mkdir -p "$BK/$(dirname "$f")"; cp "$GSZ/$f" "$BK/$f"; done
echo "    backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in "${FILES[@]}"; do cp "$BK/$f" "$GSZ/$f"; done; pm2 restart gsz >/dev/null 2>&1 || true; echo "!! restored."; }
trap 'restore' ERR
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTQwIHBhdGNoZXIg4oCUIHNob3cgY3J5cHRvL0JpbmFuY2UgcGF5bWVudCBtZXRob2RzIGF0IGNoZWNrb3V0IHJlZ2FyZGxlc3MKICAgb2YgdGhlIHZpZXdlcidzIHJlZ2lvbi4gQm90IHBheS1hY2NvdW50cyBhcmUgcmVnaW9uLWZpbHRlcmVkOyBhIGdsb2JhbC1zY29wZWQKICAgQmluYW5jZSB3YXMgZHJvcHBlZCBmb3IgUEsgdmlzaXRvcnMuIENyeXB0byBpc24ndCByZWdpb24tYm91bmQsIHNvIGFsd2F5cwogICBpbmNsdWRlIGl0IChmaWF0IG1ldGhvZHMga2VlcCByZWdpb24gZmlsdGVyaW5nKS4gSWRlbXBvdGVudDsgYWJvcnRzIG9uIGJhZCBhbmNob3IuICovCmNvbnN0IGZzID0gcmVxdWlyZSgnZnMnKTsgY29uc3QgcGF0aCA9IHJlcXVpcmUoJ3BhdGgnKTsKY29uc3QgUk9PVCA9IHByb2Nlc3MuYXJndlsyXTsgaWYgKCFST09UKSB7IGNvbnNvbGUuZXJyb3IoJ3VzYWdlOiBwYXRjaF9zdGVwMTQwLmpzIDxnc3otcm9vdD4nKTsgcHJvY2Vzcy5leGl0KDEpOyB9CmZ1bmN0aW9uIHBhdGNoKHJlbCwgZWRpdHMpIHsKICBjb25zdCBmaWxlID0gcGF0aC5qb2luKFJPT1QsIHJlbCk7IGxldCBzID0gZnMucmVhZEZpbGVTeW5jKGZpbGUsICd1dGY4Jyk7CiAgZm9yIChjb25zdCBlIG9mIGVkaXRzKSB7CiAgICBpZiAocy5pbmRleE9mKGUuZ3VhcmQpID49IDApIHsgY29uc29sZS5sb2coJ3NraXAgKGFscmVhZHkpOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsgY29udGludWU7IH0KICAgIGNvbnN0IGZpcnN0ID0gcy5pbmRleE9mKGUuZmluZCk7CiAgICBpZiAoZmlyc3QgPCAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBNSVNTOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIGlmIChzLmluZGV4T2YoZS5maW5kLCBmaXJzdCArIDEpID49IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE5PVCBVTklRVUU6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgcyA9IHMuc2xpY2UoMCwgZmlyc3QpICsgZS5yZXBsYWNlICsgcy5zbGljZShmaXJzdCArIGUuZmluZC5sZW5ndGgpOwogICAgY29uc29sZS5sb2coJ3BhdGNoZWQ6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogIH0KICBmcy53cml0ZUZpbGVTeW5jKGZpbGUsIHMpOwp9CmNvbnN0IEZJTkQgPSAiICAgICAgICAgIGNvbnN0IHZpcyA9IGFjY3RzLmZpbHRlcihhID0+IGFjY3RWaXNpYmxlKHJlZ2lvbiwgYSkpOyI7CmNvbnN0IFJFUEwgPSAiICAgICAgICAgIGNvbnN0IHZpcyA9IGFjY3RzLmZpbHRlcihhID0+IGFjY3RWaXNpYmxlKHJlZ2lvbiwgYSkgfHwgKGZ1bmN0aW9uKHgpe3ZhciBjPVN0cmluZyh4LmN1cnJlbmN5fHwnJykudG9VcHBlckNhc2UoKTt2YXIgaz1TdHJpbmcoeC5rZXl8fCcnKS50b0xvd2VyQ2FzZSgpO3JldHVybiBjPT09J1VTRFQnfHxrLmluZGV4T2YoJ2JpbmFuY2UnKT49MHx8ay5pbmRleE9mKCdjcnlwdG8nKT49MHx8ay5pbmRleE9mKCd1c2R0Jyk+PTA7fSkoYSkpOyI7CnBhdGNoKCdyb3V0ZXMvY2hlY2tvdXQuanMnLCBbCiAgeyBuYW1lOiAnY3J5cHRvLWFsd2F5cy12aXNpYmxlJywgZ3VhcmQ6ICJrLmluZGV4T2YoJ2JpbmFuY2UnKSIsIGZpbmQ6IEZJTkQsIHJlcGxhY2U6IFJFUEwgfQpdKTsKY29uc29sZS5sb2coJ0FMTCBQQVRDSEVTIEFQUExJRUQnKTsK" | base64 -d > "$TMP/p.js"
echo "==> applying"; node "$TMP/p.js" "$GSZ"
echo "==> validating"; node --check "$GSZ/routes/checkout.js"
echo "==> restarting"; pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
echo "==> waiting for app to come up"
CODE=000
for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] && echo "    homepage 200: OK (after ${i}s)" || { echo "    homepage $CODE after ${i}s"; false; }
trap - ERR; rm -rf "$TMP"
echo ""
echo "==> step140 OK ✅  Binance now shows at checkout for every region (it was being hidden for PK visitors). If it still doesn't appear, the bot's /api/pay-accounts isn't returning the Binance account — check it's active on the bot."
