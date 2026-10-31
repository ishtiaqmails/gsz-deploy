#!/usr/bin/env bash
# stepNavFix.sh — remove the "Bot Status" sidebar link: /admin/bot/status is a
# JSON status API, not a browsable page, so linking it showed raw JSON ("broken").
# Keeps the working "WhatsApp Bot" (/admin/wabot). View-only, backed up + rolled back.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3600}
TS=$(date +%s); ST="$GSZ/views/admin/_shell_top.ejs"; BAK="$ST.bak.$TS"
restore(){ echo "!! failed — rolling back"; [ -f "$BAK" ] && cp -f "$BAK" "$ST"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
cp -f "$ST" "$BAK"
export ST
node <<'NODE'
const fs=require('fs'); const F=process.env.ST;
let s=fs.readFileSync(F,'utf8');
const line='\n    <a href="/admin/bot/status" class="<%= on(\'bot\') %>"><svg viewBox="0 0 24 24"><rect x="4" y="8" width="16" height="12" rx="2"/><path d="M12 8V5M9 14h.01M15 14h.01"/></svg>Bot Status</a>';
const n=s.split(line).length-1;
if(n===0){ console.log('   Bot Status link not found (already removed?)'); }
else { s=s.split(line).join(''); fs.writeFileSync(F,s); console.log('   removed Bot Status link ('+n+')'); }
NODE
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$ST"'","utf8"),{filename:"'"$ST"'"});console.log("   _shell_top compiles OK")'
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "   health FAILED"; false; }
trap - ERR
echo "   healthy. Bot Status link removed; WhatsApp Bot kept. Backup: $BAK"
