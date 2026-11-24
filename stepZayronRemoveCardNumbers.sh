#!/usr/bin/env bash
# stepZayronRemoveCardNumbers — remove the "Card numbers" admin menu item + header link (counts now auto-sync).
# Single-string anchors (robust). Safe: backup, single-match + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp routes/admin.js "$B/admin.js.bak"
revert(){ cp "$B/admin.js.bak" routes/admin.js; pm2 restart zayron >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/o1" <<'O'
['/admin/channels/counts','Card numbers','#']
O
printf '' > "$T/n1"

cat > "$T/o2" <<'O'
<a href="/admin/channels/counts" style="padding:8px 14px;background:#fff;color:#0e1430;border:1px solid #e3e8f4;border-radius:9px;font-size:13px;font-weight:700;text-decoration:none">Card numbers</a>
O
printf '' > "$T/n2"

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2]; const F='routes/admin.js';
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync(F,'utf8');
for(const [o,n] of [['o1','n1'],['o2','n2']]){ const O=rd(o); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c);process.exit(5);} s=s.split(O).join(''); }
fs.writeFileSync(F,s); console.log('admin.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/admin.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: Card numbers removed from admin (counts auto-sync from galaxyzayron). healthz=200"
