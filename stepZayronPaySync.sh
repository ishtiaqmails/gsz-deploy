#!/usr/bin/env bash
# stepZayronPaySync — make zayron's checkout payment methods AUTO-SYNC with the Reseller Bot,
# the same way galaxyzayron does. methodsFor() now:
#   - shows only methods that are live on the shared gsz-api pay-accounts (bot toggle decides) ->
#     Meezan auto-appears when enabled on the bot, MCB never appears (not on the ledger),
#   - pulls each account's Title/Number/instructions LIVE from the bot (changes sync automatically),
#   - never renders a QR (pure account details),
#   - falls back to local ledger-mappable rows if the bot is unreachable (checkout never breaks).
# FX, numeric ids, render, /paid and paySalt are all unchanged. MCB row is also deactivated in DB.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zps; rm -rf "$W"; mkdir -p "$W/p"
cp routes/checkout.js "$W/checkout.js.bak"
revert(){ cp "$W/checkout.js.bak" routes/checkout.js; }

cat > "$W/p/o1" <<'OLD'
  async function methodsFor(region) {
    const r = await pool.query('SELECT * FROM payment_methods WHERE active ORDER BY sort, id');
    return r.rows.filter(function (m) {
      if (!region) return true;
      return m.region === 'both' || m.region === region;
    });
  }
OLD

cat > "$W/p/n1" <<'NEW'
  async function methodsFor(region) {
    const gszApi = require('../lib/gszApi');
    const r = await pool.query('SELECT * FROM payment_methods WHERE active ORDER BY sort, id');
    // only methods that settle on the shared ledger (drops MCB, which has no key)
    let rows = r.rows.filter(function (m) {
      if (gszApi.methodKey(m.name) == null) return false;
      if (!region) return true;
      return m.region === 'both' || m.region === region;
    });
    // AUTO-SYNC with the bot: the live pay-accounts decide which methods show + their details.
    let live = null;
    try {
      const pa = await gszApi.getPayAccounts();
      const accts = (pa && pa.accounts) || [];
      if (accts.length) { live = {}; accts.forEach(function (a) { live[a.key] = a; }); }
    } catch (e) { live = null; }
    if (live) {
      rows = rows.filter(function (m) { return live[gszApi.methodKey(m.name)]; }); // bot toggle = visibility
      rows = rows.map(function (m) {
        const a = live[gszApi.methodKey(m.name)];
        const c = Object.assign({}, m);
        c.qr_path = null; // never a QR — account details only
        if (a) {
          const lbl = (a.currency === 'USDT') ? 'Binance ID' : 'Account Number';
          c.fields = JSON.stringify([
            { l: 'Account Title', v: a.title || '' },
            { l: lbl, v: a.account || '' }
          ]);
          if (a.instructions) c.note = a.instructions;
        }
        return c;
      });
    } else {
      // bot unreachable: keep local ledger-mappable rows (still no MCB), just drop any QR
      rows = rows.map(function (m) { const c = Object.assign({}, m); c.qr_path = null; return c; });
    }
    return rows;
  }
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zps/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+']'); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('routes/checkout.js','o1','n1');
console.log('checkout.js PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
node --check routes/checkout.js || { echo "syntax error - reverting"; revert; exit 1; }

# deactivate MCB in the DB (not on the shared ledger; can't auto-verify)
node -e "const{pool}=require('./db');pool.query(\"UPDATE payment_methods SET active=false WHERE name ILIKE 'MCB%' RETURNING id,name\").then(r=>{console.log('MCB deactivated:',r.rows.map(x=>x.id+':'+x.name).join(',')||'(none matched)');process.exit(0)}).catch(e=>{console.log('MCB update err',e.message);process.exit(0)})"

pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
sleep 1

# verify: show the live keys and which local methods now sync-show
node -e "const{pool}=require('./db');const g=require('./lib/gszApi');(async()=>{const pa=await g.getPayAccounts().catch(()=>({}));const live=((pa&&pa.accounts)||[]).map(a=>a.key);const rows=(await pool.query('SELECT name,active FROM payment_methods ORDER BY sort,id')).rows;console.log('live ledger keys:',live.join(', ')||'(bot unreachable)');console.log('methods after sync:');rows.forEach(m=>{const k=g.methodKey(m.name);const shows=m.active&&k&&(live.length?live.indexOf(k)>=0:true);console.log('  '+m.name+' | active='+m.active+' | key='+(k||'NONE')+' | shows='+(shows?'YES':'no'));});process.exit(0)})()"
echo "DONE: payment methods now auto-sync with the bot. MCB dropped. QR off. Checkout FX unchanged."
