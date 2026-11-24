#!/usr/bin/env bash
# stepZayronAvailKey — make Buy/Trial availability key off bot_sku (reliable) instead of the
# wipe-prone reseller_pid. getPublicData's server availability key now falls back to bot_sku when
# reseller_pid is blank, so every consumer (paidLiveMap, autoTrial, product cards) resolves via the
# bridge. Also exposes servers.bot_sku on the public object, and fixes the admin trial list.
# Safe: backups, single-match anchors + auto-revert, node --check.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zak; rm -rf "$W"; mkdir -p "$W/p"
cp lib/data.js "$W/data.js.bak"
cp lib/admin/trials.js "$W/trials.js.bak"
revert(){ cp "$W/data.js.bak" lib/data.js; cp "$W/trials.js.bak" lib/admin/trials.js; }

# ---- data.js: availability key falls back to bot_sku; expose bot_sku ----
cat > "$W/p/o1" <<'OLD'
    reseller_pid: s.reseller_pid || '',
OLD
cat > "$W/p/n1" <<'NEW'
    reseller_pid: s.reseller_pid || s.bot_sku || '',
    bot_sku: s.bot_sku || '',
NEW

# ---- admin/trials.js: use bot_sku for the per-server trial state ----
cat > "$W/p/o2" <<'OLD'
      if (!r.reseller_pid) { botState[r.id] = null; continue; }
      try { botState[r.id] = !(await tt.isTrialDisabled(r.reseller_pid)); }
OLD
cat > "$W/p/n2" <<'NEW'
      if (!r.bot_sku) { botState[r.id] = null; continue; }
      try { botState[r.id] = !(await tt.isTrialDisabled(r.bot_sku)); }
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zak/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+'] in '+file); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('lib/data.js','o1','n1');
rep('lib/admin/trials.js','o2','n2');
console.log('PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
for f in lib/data.js lib/admin/trials.js; do node --check "$f" || { echo "syntax error $f - reverting"; revert; exit 1; }; done

pm2 restart zayron zayron-orders >/dev/null 2>&1 || pm2 restart zayron zayron-orders
sleep 1
echo "--- availability check (mapped servers should be sellable) ---"
node -e "const p=require('./lib/paidToggle');const{pool}=require('./db');(async()=>{const sv=(await pool.query(\"SELECT name,reseller_pid,bot_sku FROM servers WHERE bot_sku IS NOT NULL AND bot_sku<>'' ORDER BY id\")).rows;for(const s of sv){const key=s.reseller_pid||s.bot_sku;console.log(s.name,'| key='+key,'| paidLive='+(await p.isPaidLive(key)));}process.exit(0)})()"
echo "DONE: Buy/Trial now resolve via bot_sku. Mapped servers show automated; unmapped stay manual."
