#!/usr/bin/env bash
# stepZayronContentTypes — make the checkout Family/Adult chip purely self-aware from the bot product's
# `types` array (Adult shown only if the mapped product has an 'adult' type), using the 60s-cached read.
# Then re-sync plan labels so just-mapped servers (Mega) become canonical. Report content-types + unmapped.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp routes/checkout.js "$B/checkout.js.bak"
revert(){ cp "$B/checkout.js.bak" routes/checkout.js; pm2 restart zayron >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/c_o" <<'O'
      let ctAvail = false;
      try {
        let _bsku = sv.bot_sku;
        if (_bsku == null) { try { const _sr = await pool.query('SELECT bot_sku FROM servers WHERE id=$1', [o.server_id]); _bsku = _sr.rows[0] && _sr.rows[0].bot_sku; } catch (e) {} }
        if (_bsku) {
          const dispatch = require('../lib/orderDispatch');
          const t = await dispatch.resolvePackage(_bsku, o.plan_label, 'Adult');
          ctAvail = !!(t && t.ok);
        }
      } catch (e) { ctAvail = false; }
O
cat > "$T/c_n" <<'O'
      let ctAvail = false;
      try {
        let _bsku = sv.bot_sku;
        if (_bsku == null) { try { const _sr = await pool.query('SELECT bot_sku FROM servers WHERE id=$1', [o.server_id]); _bsku = _sr.rows[0] && _sr.rows[0].bot_sku; } catch (e) {} }
        if (_bsku) {
          // Self-aware content types: show Adult only if the mapped bot product has an 'adult' type (60s-cached read).
          const _prod = await gszApi.getProducts();
          const _bp = ((_prod && _prod.products) || []).find(function (y) { return String(y.sku) === String(_bsku); });
          const _types = (_bp && Array.isArray(_bp.types)) ? _bp.types.map(function (t) { return String(t.key || '').toLowerCase(); }) : [];
          ctAvail = _types.indexOf('adult') >= 0;
        }
      } catch (e) { ctAvail = false; }
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('routes/checkout.js','utf8'); const O=rd('c_o'), N=rd('c_n'); const c=s.split(O).length-1;
if(c!==1){ console.error('ANCHOR c_o x'+c); process.exit(5); }
fs.writeFileSync('routes/checkout.js', s.split(O).join(N)); console.log('routes/checkout.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/checkout.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "--- re-syncing plan labels (picks up newly-mapped servers like Mega) ---"
node -e "require('./lib/planSync').syncAll().then(r=>{console.log('planSync result:', JSON.stringify(r));process.exit(0)}).catch(e=>{console.log(e.message);process.exit(0)})"
echo "--- per server: durations + content types (from bot) + mapping ---"
node -e "
const { pool } = require('./db'); const api=require('./lib/gszApi');
(async()=>{ try{
  const prod=await api.getProducts(); const plist=(prod&&prod.products)||[];
  const srv=(await pool.query('SELECT id,name,bot_sku FROM servers ORDER BY name')).rows;
  for(const s of srv){
    const labs=(await pool.query('SELECT string_agg(label, \", \" ORDER BY sort) l FROM server_plans WHERE server_id=\$1 AND price>0',[s.id])).rows[0].l||'(none)';
    let ct='unmapped';
    if(s.bot_sku){ const bp=plist.find(y=>String(y.sku)===String(s.bot_sku)); const t=(bp&&Array.isArray(bp.types))?bp.types.map(x=>x.key).join('+'):'no-types'; ct=t; }
    console.log(' -', s.name.padEnd(22), '| '+ct.padEnd(14), '| '+labs);
  }
}catch(e){console.log(e.message)} process.exit(0); })();
"
echo "DONE: content types self-aware from bot; labels re-synced. healthz=200"
