#!/usr/bin/env bash
# stepGszVerifyInventory — fix own-inventory (and manual) orders paid via a bot payment account getting stuck in
# 'verifying' forever. The payment verifier was gated to source IN ('bot','cart'), but payment verification is about
# the PAYMENT (amount+method+screenshot), not the product. Fix: verify ANY 'verifying' order; delivery drainer covers
# the auto-deliver sources (bot/cart/inventory; manual stays admin-delivered). Bot/cart path unchanged.
# Safe: backup + single-match + revert + node --check + health loop on / (==200) + GSZ-2039 status after.
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp routes/checkout.js "$B/"
revert(){ cp "$B/checkout.js" routes/checkout.js; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# --- E1: reverifyOrder — verify any 'verifying' order (drop source gate) ---
cat > "$T/e1_o" <<'O'
      if (!o || o.status !== 'verifying' || (o.source !== 'bot' && o.source !== 'cart')) return;
O
cat > "$T/e1_n" <<'O'
      if (!o || o.status !== 'verifying') return;
O
# --- E2: drainer verify query — any 'verifying' order ---
cat > "$T/e2_o" <<'O'
      const vrows = (await pool.query("SELECT id FROM orders WHERE source IN ('bot','cart') AND status='verifying' AND created_at > now() - interval '2 hours' ORDER BY id DESC LIMIT 20")).rows;
O
cat > "$T/e2_n" <<'O'
      const vrows = (await pool.query("SELECT id FROM orders WHERE status='verifying' AND created_at > now() - interval '2 hours' ORDER BY id DESC LIMIT 20")).rows;
O
# --- E3: drainer delivery query — auto-deliver sources (add inventory; manual stays admin-delivered) ---
cat > "$T/e3_o" <<'O'
      const rows = (await pool.query("SELECT id, order_no, status, source FROM orders WHERE source IN ('bot','cart') AND status IN ('delivering','paid') ORDER BY id DESC LIMIT 20")).rows;
O
cat > "$T/e3_n" <<'O'
      const rows = (await pool.query("SELECT id, order_no, status, source FROM orders WHERE source IN ('bot','cart','inventory') AND status IN ('delivering','paid') ORDER BY id DESC LIMIT 20")).rows;
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('routes/checkout.js','utf8');
for(const [o,n] of [['e1_o','e1_n'],['e2_o','e2_n'],['e3_o','e3_n']]){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' matched x'+c);process.exit(5);} s=s.split(O).join(N); }
fs.writeFileSync('routes/checkout.js',s); console.log('routes/checkout.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; cp "$B/checkout.js" routes/checkout.js; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/checkout.js || { echo "syntax error - reverting"; cp "$B/checkout.js" routes/checkout.js; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }

echo "waiting ~25s for the drainer to check GSZ-2039..."
sleep 25
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT order_no,status,claim_result,amount_claimed FROM orders WHERE order_no='GSZ-2039'\").then(r=>{r.rows.forEach(x=>console.log('GSZ-2039 ->', JSON.stringify(x)));return p.end();}).catch(e=>{console.log('ERR',e.message);process.exit(0);});" 2>&1 | tail -3
echo "DONE: inventory/manual orders paid via a bot account now get verified. gsz http=${HC}"
echo "If GSZ-2039 still shows status=verifying with claim_result=pending, the reseller bot hasn't matched the payment alert yet — tell me and I'll check the match or we deliver it from admin."
