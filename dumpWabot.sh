#!/usr/bin/env bash
# dumpWabot.sh — read-only. How the verification bot (/opt/gsz-wabot/bot.js) receives messages,
# identifies the owner, dispatches commands, replies, and whether/how it calls the GSZ API.
set -uo pipefail
F=/opt/gsz-wabot/bot.js
echo "### size ###"; wc -l "$F"
ctx(){ awk -v pat="$1" -v n="${2:-30}" 'BEGIN{IGNORECASE=1} {L[NR]=$0} $0~pat{for(i=NR-3;i<=NR+n;i++) if(i>0&&!done[i]){printf "%4d| %s\n",i,L[i]; done[i]=1}} END{}' "$F" 2>/dev/null; }

echo; echo "### A) key hooks (upsert / text / owner / command / sendMessage / http / secret) ###"
grep -nE "messages\.upsert|ev\.on\(|conversation|extendedTextMessage|getContentType|sendMessage|reply\(|OWNER|isOwner|owner|startsWith|switch *\(|\.trim\(\)|fetch\(|axios|https?\.request|require\('node-fetch'|BASE_URL|galaxyzayron|127\.0\.0\.1:3900|localhost:3900|webhook_secret|WEBHOOK_SECRET|process\.env\." "$F" 2>/dev/null | head -60

echo; echo "### B) context around the incoming-message handler ###"
ctx "messages\.upsert" 45

echo; echo "### C) context around owner / command parsing ###"
ctx "owner|isOwner|startsWith|command|cmd\b" 18
echo "== END =="
