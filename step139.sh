#!/usr/bin/env bash
# GSZ step139 — add Binance (USDT) + TapTap (PKR) as checkout payment methods.
# Inserts the two methods into payment_methods (idempotent, skips if present),
# INACTIVE with blank details. Fill the real Binance wallet / TapTap number on
# /admin/payments, then switch each one ON. DB-only; no code/file changes.
set -euo pipefail
GSZ=/opt/gsz; TMP=$(mktemp -d)
echo "==> step139: Binance + TapTap payment methods"
echo "J3VzZSBzdHJpY3QnOwpyZXF1aXJlKCdkb3RlbnYvY29uZmlnJyk7CmNvbnN0IHsgUG9vbCB9ID0gcmVxdWlyZSgncGcnKTsKY29uc3QgcG9vbCA9IG5ldyBQb29sKHsgaG9zdDogcHJvY2Vzcy5lbnYuREJfSE9TVCB8fCAnMTI3LjAuMC4xJywgcG9ydDogKyhwcm9jZXNzLmVudi5EQl9QT1JUIHx8IDU0MzIpLCB1c2VyOiBwcm9jZXNzLmVudi5EQl9VU0VSLCBwYXNzd29yZDogcHJvY2Vzcy5lbnYuREJfUEFTUywgZGF0YWJhc2U6IHByb2Nlc3MuZW52LkRCX05BTUUgfSk7Cihhc3luYyAoKSA9PiB7CiAgYXN5bmMgZnVuY3Rpb24gZW5zdXJlKGtleSwgbmFtZSwgY3VycmVuY3ksIHNjb3BlLCBpbnN0cnVjdGlvbnMsIHNvcnQpIHsKICAgIGNvbnN0IHIgPSBhd2FpdCBwb29sLnF1ZXJ5KAogICAgICAiSU5TRVJUIElOVE8gcGF5bWVudF9tZXRob2RzKGtleSxuYW1lLGN1cnJlbmN5LHNjb3BlLGRldGFpbHMsaW5zdHJ1Y3Rpb25zLGFjdGl2ZSxzb3J0KSAiICsKICAgICAgIlNFTEVDVCAkMSwkMiwkMywkNCwnJywkNSxmYWxzZSwkNiBXSEVSRSBOT1QgRVhJU1RTIChTRUxFQ1QgMSBGUk9NIHBheW1lbnRfbWV0aG9kcyBXSEVSRSBrZXk9JDEpIFJFVFVSTklORyBpZCIsCiAgICAgIFtrZXksIG5hbWUsIGN1cnJlbmN5LCBzY29wZSwgaW5zdHJ1Y3Rpb25zLCBzb3J0XSk7CiAgICBjb25zb2xlLmxvZygoci5yb3dDb3VudCA/ICcgIGNyZWF0ZWQgJyA6ICcgIGV4aXN0cyAgJykgKyBrZXkpOwogIH0KICBhd2FpdCBlbnN1cmUoJ2JpbmFuY2UnLCAnQmluYW5jZSBQYXkgKFVTRFQpJywgJ1VTRFQnLCAnZ2xvYmFsJywgJ1NlbmQgdGhlIGV4YWN0IFVTRFQgYW1vdW50IHNob3duLCB0aGVuIHVwbG9hZCB5b3VyIHBheW1lbnQgc2NyZWVuc2hvdCBiZWxvdy4nLCA1MCk7CiAgYXdhaXQgZW5zdXJlKCd0YXB0YXAnLCAnVGFwVGFwJywgJ1BLUicsICdwaycsICdTZW5kIHRoZSBleGFjdCBhbW91bnQgdG8gdGhlIFRhcFRhcCBkZXRhaWxzIGFib3ZlLCB0aGVuIHVwbG9hZCB5b3VyIHBheW1lbnQgc2NyZWVuc2hvdCBiZWxvdy4nLCA1MSk7CiAgY29uc29sZS5sb2coJ3N0ZXAxMzkgbWlncmF0aW9uIG9rJyk7CiAgYXdhaXQgcG9vbC5lbmQoKTsKfSkoKS5jYXRjaChlID0+IHsgY29uc29sZS5lcnJvcignTUlHUkFUSU9OIEZBSUw6ICcgKyBlLm1lc3NhZ2UpOyBwcm9jZXNzLmV4aXQoMSk7IH0pOwo=" | base64 -d > "$TMP/m.js"
echo "==> migrating db"; ( cd "$GSZ" && NODE_PATH="$GSZ/node_modules" node "$TMP/m.js" )
echo "==> checking app"
CODE=000
for i in $(seq 1 20); do CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$CODE" = "200" ] && break; sleep 1; done
[ "$CODE" = "200" ] && echo "    homepage 200: OK" || echo "    homepage $CODE (app may be restarting — payment rows were still added)"
rm -rf "$TMP"
echo ""
echo "==> step139 OK ✅  Open /admin/payments — 'Binance Pay (USDT)' and 'TapTap' are now listed (inactive)."
echo "    1) Put your real Binance wallet/Pay ID + network in Binance's Details (and TapTap number/name in TapTap's Details)."
echo "    2) Tick Active on each, Save."
echo "    If they DON'T appear at checkout after activating, your live payment options come from the reseller bot — tell me and I'll give you the bot-side entry instead."
