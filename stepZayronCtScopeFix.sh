#!/usr/bin/env bash
# stepZayronCtScopeFix — the ctAvail block referenced gszApi which is only defined inside another function,
# so it always threw -> Family/Adult toggle hidden. Require the bridge inline (matches the file's pattern).
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp routes/checkout.js "$B/checkout.js.bak"
revert(){ cp "$B/checkout.js.bak" routes/checkout.js; pm2 restart zayron >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/o" <<'O'
          const _prod = await gszApi.getProducts();
O
cat > "$T/n" <<'O'
          const _prod = await require('../lib/gszApi').getProducts();
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('routes/checkout.js','utf8'); const O=rd('o'), N=rd('n'); const c=s.split(O).length-1;
if(c!==1){ console.error('ANCHOR x'+c); process.exit(5); }
fs.writeFileSync('routes/checkout.js', s.split(O).join(N)); console.log('routes/checkout.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/checkout.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: content toggle fixed (gszApi inline). Family/Adult now shows on adult-capable servers. healthz=200"
