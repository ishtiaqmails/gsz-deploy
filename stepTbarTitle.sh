#!/usr/bin/env bash
# stepTbarTitle.sh — admin top-bar title no longer truncates on phones.
# In @media(max-width:560px), .tbar h1 had flex:1 1 0 while the .sp spacer also has flex:1 1 0,
# so they split the row 50/50 and the title clipped ("Dashbo…"). Give the title its natural
# width (flex:0 1 auto) so the spacer fills the gap and the full title shows. Shared shell =
# fixes every admin page at once.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
SH="$GSZ/views/admin/_shell_top.ejs"; TS=$(date +%s)
[ -f "$SH" ] || { echo "shell not found: $SH"; exit 1; }
cp -f "$SH" "$SH.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$SH.xbak.$TS" "$SH"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> patch .tbar h1 flex"
export SH
node <<'NODE'
const fs=require('fs'); const SH=process.env.SH; let s=fs.readFileSync(SH,'utf8');
if(/\.tbar\s+h1\s*\{[^}]*?flex\s*:\s*0\s+1\s+auto/i.test(s)){ console.log('   already fixed'); process.exit(0); }
const re=/(\.tbar\s+h1\s*\{[^}]*?flex\s*:\s*)1\s+1\s+0%?/i;
const count=(s.match(/\.tbar\s+h1\s*\{[^}]*?flex\s*:\s*1\s+1\s+0%?/gi)||[]).length;
if(count!==1) throw new Error('expected exactly 1 ".tbar h1 flex:1 1 0", found '+count);
s=s.replace(re,function(m,p1){return p1+'0 1 auto';});
fs.writeFileSync(SH,s); console.log('   .tbar h1 -> flex:0 1 auto');
NODE

echo "==> compile check"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$SH"'","utf8"),{filename:"'"$SH"'"});console.log("   shell compiles OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — admin titles show in full on phones. Backup: $SH.xbak.$TS"
