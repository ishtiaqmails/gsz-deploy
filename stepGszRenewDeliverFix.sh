#!/usr/bin/env bash
# stepGszRenewDeliverFix — galaxyzayron delivery bug: when a renew times out and the code falls through to
# a fresh submitOrder, it deletes fields.renew_line IN MEMORY ONLY. The DB still has renew_line, so the
# background drainer's pollOnce polls renewStatus(submit_id) forever instead of orderStatus(order_no) ->
# the order sticks at 'delivering' and never delivers (Boss TV, Rolex). Fix: persist the deletion to the DB.
# One anchored edit in routes/checkout.js. Safe: backup, single-match + auto-revert, node --check, health loop.
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp routes/checkout.js "$B/checkout.js.bak"
revert(){ cp "$B/checkout.js.bak" routes/checkout.js; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/o" <<'O'
        try { if (o.fields && typeof o.fields === 'object') { delete o.fields.renew_line; } } catch (e) {}
O
cat > "$T/n" <<'O'
        try { if (o.fields && typeof o.fields === 'object') { delete o.fields.renew_line; await pool.query("UPDATE orders SET fields=$1 WHERE id=$2", [JSON.stringify(o.fields), o.id]); } } catch (e) {}
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
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/healthz" 2>/dev/null || echo 000); [ "$HC" != "000" ] && break; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" != "000" ] && break; done
echo "gsz port ${PORT} http=${HC}"
[ "$HC" != "000" ] || { echo "gsz not responding after restart - reverting"; revert; exit 1; }
echo "DONE: renew-fallthrough now persists cleared fields -> drainer polls orderStatus -> stuck renewals self-deliver. gsz http=${HC}"
