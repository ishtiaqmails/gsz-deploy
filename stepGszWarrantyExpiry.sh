#!/usr/bin/env bash
# stepGszWarrantyExpiry — delivery message: IPTV shows the line's expiry and NO warranty line; non-IPTV shows
# the reseller-bot warranty (fields.warranty / warranty_days), website value only as a last fallback.
# One anchored edit in lib/deliveryMsg.js. Safe: backup, single-match + auto-revert, node --check, health loop.
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp lib/deliveryMsg.js "$B/deliveryMsg.js.bak"
revert(){ cp "$B/deliveryMsg.js.bak" lib/deliveryMsg.js; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/o" <<'O'
  const warr = esc(opts.warranty);
O
cat > "$T/n" <<'O'
  // IPTV uses its own expiry (shown in the header) and carries NO warranty line. Non-IPTV uses the
  // reseller-bot warranty (fields.warranty / warranty_days); the website value is only a last fallback.
  const warr = (dt === 'iptv') ? '' : (esc(fields.warranty) || (Number(fields.warranty_days) > 0 ? (Number(fields.warranty_days) + ' Days Warranty') : '') || esc(opts.warranty));
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('lib/deliveryMsg.js','utf8'); const O=rd('o'), N=rd('n'); const c=s.split(O).length-1;
if(c!==1){ console.error('ANCHOR x'+c); process.exit(5); }
fs.writeFileSync('lib/deliveryMsg.js', s.split(O).join(N)); console.log('lib/deliveryMsg.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check lib/deliveryMsg.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }
echo "DONE: IPTV deliveries show expiry (no warranty); non-IPTV shows reseller-bot warranty. gsz http=${HC}"
