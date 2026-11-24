#!/usr/bin/env bash
# stepZayronBotSku1 — FOUNDATION for owner-mapped provisioning (no behavior change yet):
#   1. add servers.bot_sku (text, nullable) — the gsz-api product each server maps to.
#   2. add gszApi.getProducts() so admin + dispatch can list/choose bot products.
# Nothing calls these yet. Safe: backup, single-match anchors + auto-revert, node --check.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zbs1; rm -rf "$W"; mkdir -p "$W/p"
cp lib/gszApi.js "$W/gszApi.js.bak"
revert(){ cp "$W/gszApi.js.bak" lib/gszApi.js; }

# ---- TTL: add a products cache bucket ----
cat > "$W/p/o1" <<'OLD'
const TTL = { pay: 5, status: 4 };
OLD
cat > "$W/p/n1" <<'NEW'
const TTL = { pay: 5, status: 4, prod: 60 };
NEW

# ---- add getProducts() after getPayAccounts() ----
cat > "$W/p/o2" <<'OLD'
  const j = await req('GET', '/api/pay-accounts', null, 6000);
  return cset('pay', j, TTL.pay);
}
OLD
cat > "$W/p/n2" <<'NEW'
  const j = await req('GET', '/api/pay-accounts', null, 6000);
  return cset('pay', j, TTL.pay);
}
// GET /api/products -> { ok, products:[{sku,name,delivery_type,iptv_panel_id?,plans:[{plan_key,label}],types:[{key}]}] }
async function getProducts() {
  const hit = cget('prod'); if (hit !== undefined) return hit;
  const j = await req('GET', '/api/products', null, 8000);
  return cset('prod', j, TTL.prod);
}
NEW

# ---- export getProducts ----
cat > "$W/p/o3" <<'OLD'
module.exports = { configured, getPayAccounts, verifyClaim, orderStatus, submitOrder, methodKey };
OLD
cat > "$W/p/n3" <<'NEW'
module.exports = { configured, getPayAccounts, getProducts, verifyClaim, orderStatus, submitOrder, methodKey };
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zbs1/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+']'); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('lib/gszApi.js','o1','n1');
rep('lib/gszApi.js','o2','n2');
rep('lib/gszApi.js','o3','n3');
console.log('gszApi.js PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
node --check lib/gszApi.js || { echo "syntax error - reverting"; revert; exit 1; }

# add the servers.bot_sku column (idempotent)
node -e "const{pool}=require('./db');pool.query('ALTER TABLE servers ADD COLUMN IF NOT EXISTS bot_sku text').then(()=>{console.log('servers.bot_sku ready');process.exit(0)}).catch(e=>{console.log('ALTER err',e.message);process.exit(1)})"

pm2 restart zayron zayron-orders >/dev/null 2>&1 || pm2 restart zayron zayron-orders
# quick confirm getProducts works end-to-end
node -e "require('./lib/gszApi').getProducts().then(r=>console.log('getProducts OK — iptv products:',((r&&r.products)||[]).filter(p=>p.delivery_type==='iptv').length)).catch(e=>console.log('getProducts err',e.message))"
echo "DONE: foundation ready (servers.bot_sku + gszApi.getProducts). Nothing wired yet."
