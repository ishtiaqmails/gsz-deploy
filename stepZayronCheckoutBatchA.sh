#!/usr/bin/env bash
# stepZayronCheckoutBatchA — checkout batch:
#  1) exact product price (paySalt neutered -> no +1-3 rupee; quote PKR exact)
#  2) require a payment screenshot; drop the name/account fields
#  3) Meezan/any method: owner extra fields (e.g. IBAN) merge under the bot account details
#  4) Wise -> verifies via Meezan (methodKey maps wise->meezan)
# Binance USDT keeps the method's buffer % (set it in admin to match galaxyzayron).
# Files: lib/paySalt.js, routes/checkout.js, lib/gszApi.js. File-based anchors (template literals safe).
# Safe: backup all, single-match anchors + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp lib/paySalt.js "$B/"; cp routes/checkout.js "$B/"; cp lib/gszApi.js "$B/"
revert(){ cp "$B/paySalt.js" lib/paySalt.js; cp "$B/checkout.js" routes/checkout.js; cp "$B/gszApi.js" lib/gszApi.js; pm2 restart zayron >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# ---------- paySalt: exact amount ----------
cat > "$T/ps_o" <<'O'
async function ensure(pool, order, method, baseQ) {
  if (!baseQ) return null;
  if (order.pay_method_id === method.id && order.pay_amount != null && order.status === 'awaiting_payment') {
    const amt = Number(order.pay_amount);
    const cur = order.pay_currency || baseQ.currency;
    return { amount: amt, currency: cur, rate: Number(order.fx_rate) || baseQ.rate || 1, display: fmt(amt, cur) };
  }
  const salted = await uniqueAmount(pool, baseQ.amount, baseQ.currency, order.id);
  try {
    await pool.query("UPDATE orders SET pay_amount=$1, pay_currency=$2, pay_method_id=$3, fx_rate=$4 WHERE id=$5 AND status='awaiting_payment'",
      [salted, baseQ.currency, method.id, baseQ.rate || 1, order.id]);
  } catch (e) {}
  order.pay_amount = salted; order.pay_method_id = method.id; order.pay_currency = baseQ.currency; order.fx_rate = baseQ.rate || 1;
  return { amount: salted, currency: baseQ.currency, rate: baseQ.rate || 1, display: fmt(salted, baseQ.currency) };
}
O
cat > "$T/ps_n" <<'N'
async function ensure(pool, order, method, baseQ) {
  if (!baseQ) return null;
  const amt = baseQ.amount; // exact product price — no unique-amount salt
  try {
    await pool.query("UPDATE orders SET pay_amount=$1, pay_currency=$2, pay_method_id=$3, fx_rate=$4 WHERE id=$5 AND status='awaiting_payment'",
      [amt, baseQ.currency, method.id, baseQ.rate || 1, order.id]);
  } catch (e) {}
  order.pay_amount = amt; order.pay_method_id = method.id; order.pay_currency = baseQ.currency; order.fx_rate = baseQ.rate || 1;
  return { amount: amt, currency: baseQ.currency, rate: baseQ.rate || 1, display: fmt(amt, baseQ.currency) };
}
N

# ---------- gszApi: Wise -> meezan ----------
cat > "$T/gk_o" <<'O'
function methodKey(s) { s = String(s || '').toLowerCase(); if (/binance|usdt|crypto/.test(s)) return 'binance'; if (/naya/.test(s)) return 'nayapay'; if (/meezan/.test(s)) return 'meezan'; return null; }
O
cat > "$T/gk_n" <<'N'
function methodKey(s) { s = String(s || '').toLowerCase(); if (/binance|usdt|crypto/.test(s)) return 'binance'; if (/naya/.test(s)) return 'nayapay'; if (/meezan|wise/.test(s)) return 'meezan'; return null; }
N

# ---------- checkout E1: quote PKR exact ----------
cat > "$T/c1_o" <<'O'
  async function quote(pkrBase, method) {
    const buf = 1 + (Number(method.buffer) || 0) / 100;
    if (method.pay_currency === 'PKR') {
      return { amount: Math.ceil(pkrBase * buf / 10) * 10, currency: 'PKR', rate: 1, display: 'PKR ' + (Math.ceil(pkrBase * buf / 10) * 10).toLocaleString('en-US') };
    }
    if (method.pay_currency === 'USDT') {
      const usd = await usdRate();
      if (!usd) return null;
      const v = Math.ceil(pkrBase * usd * buf * 100) / 100;
      return { amount: v, currency: 'USDT', rate: usd, display: v.toFixed(2) + ' USDT' };
    }
    const v = Math.ceil(pkrBase * buf);
    return { amount: v, currency: 'PKR', rate: 1, display: 'PKR ' + v.toLocaleString('en-US') };
  }
O
cat > "$T/c1_n" <<'N'
  async function quote(pkrBase, method) {
    const buf = 1 + (Number(method.buffer) || 0) / 100;
    if (method.pay_currency === 'PKR') {
      const v = Math.round(pkrBase);
      return { amount: v, currency: 'PKR', rate: 1, display: 'PKR ' + v.toLocaleString('en-US') };
    }
    if (method.pay_currency === 'USDT') {
      const usd = await usdRate();
      if (!usd) return null;
      const v = Math.ceil(pkrBase * usd * buf * 100) / 100;
      return { amount: v, currency: 'USDT', rate: usd, display: v.toFixed(2) + ' USDT' };
    }
    const v = Math.round(pkrBase);
    return { amount: v, currency: 'PKR', rate: 1, display: 'PKR ' + v.toLocaleString('en-US') };
  }
N

# ---------- checkout E5: methodsFor merge extra fields (IBAN) ----------
cat > "$T/c5_o" <<'O'
        if (a) {
          const lbl = (a.currency === 'USDT') ? 'Binance ID' : 'Account Number';
          c.fields = JSON.stringify([
            { l: 'Account Title', v: a.title || '' },
            { l: lbl, v: a.account || '' }
          ]);
          if (a.instructions) c.note = a.instructions;
        }
O
cat > "$T/c5_n" <<'N'
        if (a) {
          const lbl = (a.currency === 'USDT') ? 'Binance ID' : 'Account Number';
          const _extra = parseFields(m).filter(function (f) { const L = String(f.l || f.label || '').toLowerCase(); return L && L !== 'account title' && L !== 'account number' && L !== 'binance id'; });
          c.fields = JSON.stringify([
            { l: 'Account Title', v: a.title || '' },
            { l: lbl, v: a.account || '' }
          ].concat(_extra));
          if (a.instructions) c.note = a.instructions;
        }
N

# ---------- checkout E4: require screenshot (server backstop) ----------
cat > "$T/c4_o" <<'O'
      const b = req.body || {};
      let ordF = [];
O
cat > "$T/c4_n" <<'N'
      const b = req.body || {};
      if (!req.file) return res.redirect('/checkout/' + o.ref);
      let ordF = [];
N

# ---------- checkout E7a: zkAsk -> screenshot upload ----------
cat > "$T/c7a_o" <<'O'
    var a='<div class="zk-askh">Your payment details (so we can confirm it)</div>';
    if(obj.binance){ a+='<div class="zk-r"><label>Binance name</label><input type="text" class="zk-fld" id="zkSender" placeholder="Your Binance name"></div>'; }
    else { a+='<div class="zk-r"><label>Account title (sender)</label><input type="text" class="zk-fld" id="zkSender" placeholder="Name you paid from"></div><div class="zk-r"><label>Account number</label><input type="text" class="zk-fld" id="zkAcct" inputmode="numeric" placeholder="Your account number"></div>'; }
    document.getElementById('zkAsk').innerHTML=a;
O
cat > "$T/c7a_n" <<'N'
    var a='<div class="zk-askh">Upload your payment screenshot</div><div class="zk-r"><input type="file" class="zk-fld" id="zkProof" accept="image/*"><div style="font-size:10.5px;color:#94a3b8;margin-top:5px">A clear screenshot of your transfer confirmation. Required so we can verify it.</div></div>';
    document.getElementById('zkAsk').innerHTML=a;
N

# ---------- checkout E7b: zkPaid require file ----------
cat > "$T/c7b_o" <<'O'
    var sender=(document.getElementById('zkSender')||{}).value||'';
    if(!sender.trim()){ alert('Please enter your sender name so we can match your payment.'); return; }
    var fd=new FormData();
    fd.append('method_id', ZK_SEL);
    fd.append('payer_name', sender);
    fd.append('payer_last4', CUR.binance ? '' : ((document.getElementById('zkAcct')||{}).value||''));
O
cat > "$T/c7b_n" <<'N'
    var pf=document.getElementById('zkProof');
    var file=(pf&&pf.files&&pf.files[0])||null;
    if(!file){ alert('Please upload a screenshot of your payment so we can verify it.'); return; }
    var fd=new FormData();
    fd.append('method_id', ZK_SEL);
    fd.append('proof', file);
N

# ---------- checkout E8: note copy ----------
cat > "$T/c8_o" <<'O'
        <div class="zk-note">Auto-verified from your bank alert &mdash; no screenshot needed</div>
O
cat > "$T/c8_n" <<'N'
        <div class="zk-note">Upload your payment screenshot above, then tap the button &mdash; we verify it fast.</div>
N

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){
  let s=fs.readFileSync(file,'utf8');
  for(const [o,n] of pairs){ const O=rd(o), N=rd(n); const c=s.split(O).length-1; if(c!==1){ console.error('ANCHOR '+o+' x'+c+' in '+file); process.exit(5);} s=s.split(O).join(N); }
  fs.writeFileSync(file,s); console.log(file+' PATCHED OK');
}
patch('lib/paySalt.js', [['ps_o','ps_n']]);
patch('lib/gszApi.js', [['gk_o','gk_n']]);
patch('routes/checkout.js', [['c1_o','c1_n'],['c5_o','c5_n'],['c4_o','c4_n'],['c7a_o','c7a_n'],['c7b_o','c7b_n'],['c8_o','c8_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check lib/paySalt.js && node --check lib/gszApi.js && node --check routes/checkout.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: exact price, required screenshot, no name field, IBAN merge, Wise->Meezan. healthz=200"
