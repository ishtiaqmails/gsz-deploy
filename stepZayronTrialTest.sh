#!/usr/bin/env bash
# stepZayronTrialTest — prove provisioning end-to-end WITHOUT a paid credit and WITHOUT going live:
# generate a TRIAL line on a mapped server through the gsz-api bridge, poll until the bot delivers
# it, then send the line to your WhatsApp via the Verification Bot. Store stays in Manual the whole
# time. Adds gszApi.generateTrial/trialStatus (mirrors galaxyzayron). Safe: backup + anchors + check.
set -e
Z=/opt/zayron; cd "$Z"
TEST_SKU="${1:-SKU-00042}"      # default Filex (cheapest); pass another sku as arg 1 to override
TEST_TO="${2:-923193459191}"    # your WhatsApp; pass as arg 2 to override
W=/tmp/ztt; rm -rf "$W"; mkdir -p "$W/p"
cp lib/gszApi.js "$W/gszApi.js.bak"
revert(){ cp "$W/gszApi.js.bak" lib/gszApi.js; }

# add trial client methods after submitOrder
cat > "$W/p/o1" <<'OLD'
function submitOrder(payload) { return req('POST', '/api/submit-order', payload, 30000); }
OLD
cat > "$W/p/n1" <<'NEW'
function submitOrder(payload) { return req('POST', '/api/submit-order', payload, 30000); }
// trial provisioning (for test/verification): POST /api/generate-trial, GET /api/trial-status/:rid
function generateTrial(payload) { return req('POST', '/api/generate-trial', payload, 30000); }
function trialStatus(rid) { return req('GET', '/api/trial-status/' + encodeURIComponent(rid), null, 10000); }
NEW

cat > "$W/p/o2" <<'OLD'
module.exports = { configured, getPayAccounts, getProducts, verifyClaim, orderStatus, submitOrder, methodKey };
OLD
cat > "$W/p/n2" <<'NEW'
module.exports = { configured, getPayAccounts, getProducts, verifyClaim, orderStatus, submitOrder, generateTrial, trialStatus, methodKey };
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/ztt/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+']'); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('lib/gszApi.js','o1','n1');
rep('lib/gszApi.js','o2','n2');
console.log('gszApi.js PATCHED OK');
APPLY
node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
node --check lib/gszApi.js || { echo "syntax error - reverting"; revert; exit 1; }

echo "--- running trial provisioning test on $TEST_SKU -> $TEST_TO ---"
TEST_SKU="$TEST_SKU" TEST_TO="$TEST_TO" node <<'NODE'
const g = require('./lib/gszApi'); const w = require('./lib/waSend');
const SKU = process.env.TEST_SKU, TO = process.env.TEST_TO, RID = 'ZTRIAL-' + Date.now();
(async () => {
  console.log('generate-trial', SKU, 'rid', RID);
  const gen = await g.generateTrial({ sku: SKU, customer_ref: 'zayron-provtest', request_id: RID }).catch(e => ({ ok:false, error:e.message }));
  console.log('generate =>', JSON.stringify(gen));
  if (!gen || gen.ok === false) { console.log('GENERATE FAILED'); process.exit(0); }
  if (gen.status === 'failed') { console.log('trial NOT supported for', SKU, '— try another mapped sku (pass it as arg 1)'); process.exit(0); }
  let st = null;
  for (let i = 0; i < 18; i++) {
    await new Promise(r => setTimeout(r, 5000));
    st = await g.trialStatus(RID).catch(e => ({ status:'err', error:e.message }));
    console.log('poll ' + (i+1) + ' =>', st && st.status);
    if (st && (st.status === 'done' || st.status === 'failed')) break;
  }
  if (st && st.status === 'done') {
    console.log('\nTRIAL LINE PROVISIONED:\n' + (st.credentials || '(no creds text)'));
    const msg = 'Zayron provisioning test (trial line via bridge)\n\n' + (st.credentials || '');
    const r = await w.send(TO, msg);
    console.log('\ndelivery WhatsApp =>', JSON.stringify(r));
    console.log(r && r.ok ? '\nSUCCESS: provisioning + delivery both work end-to-end.' : '\nProvisioned OK but WhatsApp send failed — check waSend.');
  } else {
    console.log('\nDid not complete in ~90s. status=', st && st.status, 'err=', st && st.error, '\n(the bot may still finish — re-poll, or check the panel.)');
  }
  process.exit(0);
})();
NODE
echo "DONE: trial provisioning test finished. Store still in Manual — nothing customer-facing changed."
