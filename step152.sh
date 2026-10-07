#!/usr/bin/env bash
set -euo pipefail
BOT=/opt/gsz-wabot
TS=$(date +%Y%m%d-%H%M%S)
BK="$BOT/bot.js.bak-step152-$TS"
echo "==> step152: verification bot — fix 'Waiting for this message'"
[ -f "$BOT/bot.js" ] || { echo "!! $BOT/bot.js not found"; exit 1; }
cp "$BOT/bot.js" "$BK"
echo "    backup: $BK"

restore(){ echo "!! error — restoring bot.js"; cp "$BK" "$BOT/bot.js" 2>/dev/null || true; }
trap 'restore' ERR

PATCHER=$(mktemp /tmp/patch_step152.XXXXXX.js)
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTUyIHBhdGNoZXIg4oCUIGZpeCAiV2FpdGluZyBmb3IgdGhpcyBtZXNzYWdlIiBvbiB0aGUgR1NaIHZlcmlmaWNhdGlvbiBib3QuCiAgIFJvb3QgY2F1c2U6IG1ha2VXQVNvY2tldCgpIGhhZCBubyBnZXRNZXNzYWdlKCkgY2FsbGJhY2ssIHNvIHdoZW4gYSByZWNpcGllbnQncwogICBwaG9uZSBmYWlscyB0byBkZWNyeXB0IGEgbWVzc2FnZSBhbmQgYXNrcyB0aGUgYm90IHRvIHJlc2VuZCBpdCAocmV0cnkgcmVjZWlwdCksCiAgIHRoZSBib3QgaGFzIG5vdGhpbmcgdG8gaGFuZCBiYWNrIGFuZCB0aGUgcmVjaXBpZW50IHN0YXlzIHN0dWNrIGZvcmV2ZXIuCiAgIEZpeDoga2VlcCBhIHNtYWxsIGluLW1lbW9yeSBzdG9yZSBvZiB0aGUgbWVzc2FnZXMgdGhlIGJvdCBzZW5kcywgZ2l2ZSB0aGUKICAgc29ja2V0IGdldE1lc3NhZ2UoKSttc2dSZXRyeUNvdW50ZXJDYWNoZSwgYW5kIHJlbWVtYmVyIGV2ZXJ5IG91dGdvaW5nIG1lc3NhZ2UuCiAgIFB1cmUgcGx1bWJpbmcg4oCUIGRvZXMgbm90IGNoYW5nZSB3aGF0L2hvdyBtZXNzYWdlcyBhcmUgY29tcG9zZWQuIElkZW1wb3RlbnQuICovCmNvbnN0IGZzID0gcmVxdWlyZSgnZnMnKTsgY29uc3QgcGF0aCA9IHJlcXVpcmUoJ3BhdGgnKTsKY29uc3QgUk9PVCA9IHByb2Nlc3MuYXJndlsyXTsgaWYgKCFST09UKSB7IGNvbnNvbGUuZXJyb3IoJ3VzYWdlOiBub2RlIHBhdGNoX3N0ZXAxNTIuanMgPGdzei13YWJvdC1kaXI+Jyk7IHByb2Nlc3MuZXhpdCgxKTsgfQpmdW5jdGlvbiBwYXRjaChyZWwsIGVkaXRzKSB7CiAgY29uc3QgZmlsZSA9IHBhdGguam9pbihST09ULCByZWwpOyBsZXQgcyA9IGZzLnJlYWRGaWxlU3luYyhmaWxlLCAndXRmOCcpOwogIGZvciAoY29uc3QgZSBvZiBlZGl0cykgewogICAgaWYgKHMuaW5kZXhPZihlLmd1YXJkKSA+PSAwKSB7IGNvbnNvbGUubG9nKCdza2lwIChhbHJlYWR5KTogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7IGNvbnRpbnVlOyB9CiAgICBjb25zdCBmaXJzdCA9IHMuaW5kZXhPZihlLmZpbmQpOwogICAgaWYgKGZpcnN0IDwgMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTUlTUzogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgICBpZiAocy5pbmRleE9mKGUuZmluZCwgZmlyc3QgKyAxKSA+PSAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBOT1QgVU5JUVVFOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIHMgPSBzLnNsaWNlKDAsIGZpcnN0KSArIGUucmVwbGFjZSArIHMuc2xpY2UoZmlyc3QgKyBlLmZpbmQubGVuZ3RoKTsKICAgIGNvbnNvbGUubG9nKCdwYXRjaGVkOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICB9CiAgZnMud3JpdGVGaWxlU3luYyhmaWxlLCBzKTsKfQoKLyogQSkgc2VudC1tZXNzYWdlIHN0b3JlICsgcmV0cnkgY2FjaGUgKHRvcC1sZXZlbCBzdGF0ZSkgKi8KY29uc3QgQV9GSU5EID0gImxldCBjb25uU3RhdGUgPSAnY29ubmVjdGluZyc7IjsKY29uc3QgQV9SRVBMID0gImxldCBjb25uU3RhdGUgPSAnY29ubmVjdGluZyc7XG4iCisgIi8qIC0tLSBzdGVwMTUyOiByZW1lbWJlciBzZW50IG1lc3NhZ2VzIHNvIHdlIGNhbiBhbnN3ZXIgZGVjcnlwdCByZXRyeS1yZWNlaXB0cyAoZml4ZXMgXCJXYWl0aW5nIGZvciB0aGlzIG1lc3NhZ2VcIikgLS0tICovXG4iCisgImNvbnN0IHNlbnRTdG9yZSA9IG5ldyBNYXAoKTtcbiIKKyAiZnVuY3Rpb24gcmVtZW1iZXJTZW50KHdhbSkgeyB0cnkgeyBpZiAod2FtICYmIHdhbS5rZXkgJiYgd2FtLmtleS5pZCAmJiB3YW0ubWVzc2FnZSkgeyBzZW50U3RvcmUuc2V0KHdhbS5rZXkuaWQsIHdhbS5tZXNzYWdlKTsgaWYgKHNlbnRTdG9yZS5zaXplID4gMTAwMCkgeyBjb25zdCBrID0gc2VudFN0b3JlLmtleXMoKS5uZXh0KCkudmFsdWU7IHNlbnRTdG9yZS5kZWxldGUoayk7IH0gfSB9IGNhdGNoIChlKSB7fSB9XG4iCisgImNvbnN0IG1zZ1JldHJ5Q291bnRlckNhY2hlID0gKCgpID0+IHsgY29uc3QgbSA9IG5ldyBNYXAoKTsgcmV0dXJuIHsgZ2V0OiAoaykgPT4gbS5nZXQoayksIHNldDogKGssIHYpID0+IG0uc2V0KGssIHYpLCBkZWw6IChrKSA9PiBtLmRlbGV0ZShrKSwgZmx1c2hBbGw6ICgpID0+IG0uY2xlYXIoKSB9OyB9KSgpOyI7CgovKiBCKSBzb2NrZXQgY29uZmlnOiBhZGQgbXNnUmV0cnlDb3VudGVyQ2FjaGUgKyBnZXRNZXNzYWdlICovCmNvbnN0IEJfRklORCA9ICIgICAgbG9nZ2VyLCBtYXJrT25saW5lT25Db25uZWN0OiBmYWxzZSwgc3luY0Z1bGxIaXN0b3J5OiBmYWxzZVxuICB9KTsiOwpjb25zdCBCX1JFUEwgPSAiICAgIGxvZ2dlciwgbWFya09ubGluZU9uQ29ubmVjdDogZmFsc2UsIHN5bmNGdWxsSGlzdG9yeTogZmFsc2UsXG4iCisgIiAgICBtc2dSZXRyeUNvdW50ZXJDYWNoZSxcbiIKKyAiICAgIGdldE1lc3NhZ2U6IGFzeW5jIChrZXkpID0+IHsgdHJ5IHsgY29uc3QgbSA9IHNlbnRTdG9yZS5nZXQoa2V5LmlkKTsgaWYgKG0pIHJldHVybiBtOyB9IGNhdGNoIChlKSB7fSByZXR1cm4gdW5kZWZpbmVkOyB9XG4iCisgIiAgfSk7IjsKCi8qIEMpIHJlbWVtYmVyIHRoZSByZXBseSB3ZSBzZW5kIGZyb20gbWVzc2FnZXMudXBzZXJ0ICovCmNvbnN0IENfRklORCA9ICIgICAgICAgIGF3YWl0IHNvY2suc2VuZE1lc3NhZ2UoamlkLCB7IHRleHQ6IHJlc3AucmVwbHkgfSk7IjsKY29uc3QgQ19SRVBMID0gIiAgICAgICAgcmVtZW1iZXJTZW50KGF3YWl0IHNvY2suc2VuZE1lc3NhZ2UoamlkLCB7IHRleHQ6IHJlc3AucmVwbHkgfSkpOyI7CgovKiBEKSByZW1lbWJlciB0aGUgbWVzc2FnZSB3ZSBzZW5kIGZyb20gdGhlIC9zZW5kIEFQSSAqLwpjb25zdCBEX0ZJTkQgPSAiICAgICAgICBjb25zdCByID0gYXdhaXQgc29jay5zZW5kTWVzc2FnZShqaWQsIHsgdGV4dDogU3RyaW5nKHRleHQpIH0pOyI7CmNvbnN0IERfUkVQTCA9ICIgICAgICAgIGNvbnN0IHIgPSBhd2FpdCBzb2NrLnNlbmRNZXNzYWdlKGppZCwgeyB0ZXh0OiBTdHJpbmcodGV4dCkgfSk7IHJlbWVtYmVyU2VudChyKTsiOwoKcGF0Y2goJ2JvdC5qcycsIFsKICB7IG5hbWU6ICdzZW50LXN0b3JlJywgICBndWFyZDogJ2NvbnN0IHNlbnRTdG9yZSA9IG5ldyBNYXAoKTsnLCBmaW5kOiBBX0ZJTkQsIHJlcGxhY2U6IEFfUkVQTCB9LAogIHsgbmFtZTogJ2dldC1tZXNzYWdlJywgIGd1YXJkOiAnZ2V0TWVzc2FnZTogYXN5bmMgKGtleSknLCAgICAgICBmaW5kOiBCX0ZJTkQsIHJlcGxhY2U6IEJfUkVQTCB9LAogIHsgbmFtZTogJ3JlbWVtYmVyLXJlcGx5JywgZ3VhcmQ6ICdyZW1lbWJlclNlbnQoYXdhaXQgc29jay5zZW5kTWVzc2FnZShqaWQsIHsgdGV4dDogcmVzcC5yZXBseSB9KSknLCBmaW5kOiBDX0ZJTkQsIHJlcGxhY2U6IENfUkVQTCB9LAogIHsgbmFtZTogJ3JlbWVtYmVyLXNlbmQnLCAgZ3VhcmQ6ICdyZW1lbWJlclNlbnQociknLCBmaW5kOiBEX0ZJTkQsIHJlcGxhY2U6IERfUkVQTCB9Cl0pOwpjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOwo=" | base64 -d > "$PATCHER"

echo "==> applying"
node "$PATCHER" "$BOT"

echo "==> validating"
node --check "$BOT/bot.js" && echo "    node --check ok"

echo "==> restarting gszwabot"
pm2 restart gszwabot >/dev/null 2>&1 || pm2 restart gszwabot
# health-check via the bot's own secret-gated /health
SEC=$(grep -E '^WA_WEBHOOK_SECRET=' "$BOT/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"'"' | tr -d '\r')
PORT=$(grep -E '^BOT_PORT=' "$BOT/.env" | head -1 | cut -d= -f2- | tr -d '\r'); PORT=${PORT:-8095}
OKJSON=""
for i in $(seq 1 25); do sleep 1; OKJSON=$(curl -s -H "x-wa-secret: $SEC" "http://127.0.0.1:$PORT/health" 2>/dev/null || true); echo "$OKJSON" | grep -q '"ok":true' && break; done
if echo "$OKJSON" | grep -q '"ok":true'; then
  echo "    health: $OKJSON (after ${i}s)"
else
  echo "    health check inconclusive after ${i}s: ${OKJSON:-<no response>}"
  echo "    (checking the process is online instead)"
  pm2 describe gszwabot 2>/dev/null | grep -E 'status' | head -1 || true
fi
# hard gate: process must be online
pm2 jlist 2>/dev/null | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const a=JSON.parse(s||'[]');const b=a.find(x=>x.name==='gszwabot');if(!b||b.pm2_env.status!=='online'){console.error('gszwabot not online');process.exit(1)}console.log('    gszwabot: online')})"

rm -f "$PATCHER"
trap - ERR
echo ""
echo "==> step152 OK  getMessage resend handler is live. When a phone can't decrypt a message it now gets a proper resend instead of being stuck on 'Waiting for this message'. Applies to all recipients from now on. (Note: messages the bot sent BEFORE this restart can't be recovered — only new sends.)"
