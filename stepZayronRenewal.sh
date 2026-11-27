#!/usr/bin/env bash
# stepZayronRenewal — true IPTV renewal on zayron.tv (like galaxyzayron). Renew button creates a kind='renewal'
# order carrying the existing line (renew_username + renew_of); the worker extends that line via the bridge
# (/api/renew, HTML-clean username + content type), polls renewStatus, delivers the extended line (same creds, new
# expiry) with the premium message + owner alert; fresh-line fallback if the panel can't extend. New-order path
# untouched. Adds renew_of/renew_rid columns. Safe: backup + atomic single-match + revert + node --check + health.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
for f in lib/gszApi.js lib/orderDispatch.js lib/orderWorker.js routes/account.js routes/checkout.js; do cp "$f" "$B/$(basename $f)"; done
revert(){ for f in gszApi.js orderDispatch.js orderWorker.js; do cp "$B/$f" "lib/$f"; done; cp "$B/account.js" routes/account.js; cp "$B/checkout.js" routes/checkout.js; pm2 restart zayron >/dev/null 2>&1 || true; pm2 restart zayron-orders >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# ===== columns =====
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();p.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS renew_of text, ADD COLUMN IF NOT EXISTS renew_rid text').then(()=>{console.log('renew_of/renew_rid columns OK');return p.end();}).catch(e=>{console.log('ALTER ERR',e.message);process.exit(2);});" || { echo "alter failed - aborting"; rm -rf "$T"; exit 1; }

# ===== gszApi: renew + renewStatus =====
cat > "$T/g1_o" <<'O'
function notify(payload) { return req('POST', '/api/notify', payload, 6000); }
O
cat > "$T/g1_n" <<'O'
function notify(payload) { return req('POST', '/api/notify', payload, 6000); }
function renew(payload) { return req('POST', '/api/renew', payload, 15000); }
function renewStatus(rid) { return req('GET', '/api/renew-status/' + encodeURIComponent(rid), null, 8000); }
O
cat > "$T/g2_o" <<'O'
module.exports = { configured, getPayAccounts, getProducts, verifyClaim, notify, orderStatus, submitOrder, generateTrial, trialStatus, methodKey };
O
cat > "$T/g2_n" <<'O'
module.exports = { configured, getPayAccounts, getProducts, verifyClaim, notify, renew, renewStatus, orderStatus, submitOrder, generateTrial, trialStatus, methodKey };
O

# ===== orderDispatch: renewLine + pollRenew =====
cat > "$T/d1_o" <<'O'
module.exports = { resolvePackage, submit, poll };
O
cat > "$T/d1_n" <<'O'
async function renewLine(opts) {
  const o = opts || {};
  return gszApi.renew({ renewal_id: o.renewal_id, sku: o.sku, username: o.username, raw: o.raw || '', plan_key: o.plan_key, version: o.version || 'family', source: 'zayron-web' });
}
async function pollRenew(rid) {
  try {
    const rs = await gszApi.renewStatus(rid);
    if (!rs || rs.ok === false) return { status: 'pending' };
    if (rs.status === 'done') return { status: 'done', renew: true, credentials: rs.credentials || '', new_expires_at: rs.new_expires_at || null };
    if (rs.status === 'failed') return { status: 'failed', error: rs.error || 'renew failed' };
    return { status: 'pending' };
  } catch (e) { return { status: 'error', error: e.message }; }
}
module.exports = { resolvePackage, submit, poll, renewLine, pollRenew };
O

# ===== orderWorker: dispatchOrder renewal branch =====
cat > "$T/w1_o" <<'O'
    // renewals aren't wired through the bridge yet — hand to manual review rather than mis-provision
    if (order.kind === 'renewal') {
      if (dryRun) return { ok: false, error: 'renewal (manual)' };
      await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2",
        ['Renewal — extend the line by hand, then set the details here', order.id]);
      return { ok: false, error: 'renewal manual' };
    }
O
cat > "$T/w1_n" <<'O'
    // renewals: extend the existing line through the bridge; a fresh line only if the panel can't extend.
    if (order.kind === 'renewal') {
      if (dryRun) return { ok: false, error: 'renewal (dryrun)' };
      if (!sv.bot_sku) { await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2", ['Renewal — server not mapped to a bot product', order.id]); return { ok: false, error: 'not mapped' }; }
      const rres = await dispatch.resolvePackage(sv.bot_sku, order.plan_label, order.content_type);
      if (!rres.ok) { await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2", ['Renewal — could not resolve plan: ' + rres.error, order.id]); return { ok: false, error: rres.error }; }
      const ru = String(order.renew_username || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
      if (!ru) { await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2", ['Renewal — no line username on file', order.id]); return { ok: false, error: 'no renew username' }; }
      let rr = null; try { rr = await dispatch.renewLine({ renewal_id: 'ren-' + order.ref, sku: rres.sku, username: ru, plan_key: rres.plan_key, version: String(order.content_type || '').toLowerCase() }); } catch (e) { rr = { ok: false, error: e.message }; }
      if (rr && rr.ok !== false) {
        await pool.query("UPDATE orders SET bot_job_id=$1, renew_rid=$2, status='provisioning', updated_at=now() WHERE id=$3", [String(order.id), String(rr.request_id || ('ren-' + order.ref)), order.id]);
        log.log('[dispatch]', order.ref, '-> renew (' + ru + ')');
        return { ok: true, jobId: order.ref };
      }
      const sr = await dispatch.submit({ ref: order.ref, sku: rres.sku, plan_key: rres.plan_key, type: rres.type, planLabel: order.plan_label, productName: sv.name });
      if (!sr || sr.ok === false) { await pool.query("UPDATE orders SET status='review', note=$1, updated_at=now() WHERE id=$2", ['Renewal+submit failed: ' + ((sr && (sr.error || sr.reason)) || 'unknown'), order.id]); return { ok: false, error: 'renew submit failed' }; }
      await pool.query("UPDATE orders SET bot_job_id=$1, status='provisioning', updated_at=now() WHERE id=$2", [String(order.id), order.id]);
      log.log('[dispatch]', order.ref, '-> renew fallback submit');
      return { ok: true, jobId: order.ref };
    }
O

# ===== orderWorker: runCollect poll branch + renewal finalize =====
cat > "$T/w2_o" <<'O'
    for (const o of rows) {
      const p = await dispatch.poll(o.ref);
      if (p.status === 'done' && p.result) {
O
cat > "$T/w2_n" <<'O'
    for (const o of rows) {
      const p = (o.kind === 'renewal' && o.renew_rid) ? await dispatch.pollRenew(String(o.renew_rid)) : await dispatch.poll(o.ref);
      if (p.status === 'done' && p.renew) {
        let exp = null; if (p.new_expires_at) { const d0 = new Date(p.new_expires_at); if (!isNaN(d0.getTime())) exp = d0; }
        if (!exp) { const mo = monthsFromLabel(o.plan_label); if (mo > 0) { const d1 = new Date(o.expires_at || Date.now()); d1.setMonth(d1.getMonth() + mo); exp = d1; } }
        let orig = {}; try { if (o.renew_of) orig = (await pool.query("SELECT line_pass, line_url FROM orders WHERE ref=$1", [o.renew_of])).rows[0] || {}; } catch (e) {}
        const ru = String(o.renew_username || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
        await pool.query("UPDATE orders SET status='delivered', line_user=$1, line_pass=$2, line_url=$3, expires_at=COALESCE($4::timestamptz, expires_at), updated_at=now() WHERE id=$5", [ru || null, orig.line_pass || null, orig.line_url || null, exp ? exp.toISOString() : null, o.id]);
        log.log('[renewed]', o.ref, ru);
        try { await notifyDelivered(Object.assign({}, o, { line_user: ru, line_pass: orig.line_pass, line_url: orig.line_url }), { username: ru, password: orig.line_pass, host: orig.line_url }, orig.line_url, exp, null); } catch (e) { try { log.log('[renew-notify-fail]', o.ref, e.message); } catch (_) {} }
        try { await require('./notifyOwner').notifyOwner(pool, o.id, 'delivered'); } catch (e) {}
        done++;
      } else if (p.status === 'done' && p.result) {
O

# ===== account: Renew button carries the original order =====
cat > "$T/a1_o" <<'O'
    <a class="za-btn" href="/checkout?s=${esc(o.server_slug || '')}&plan=${encodeURIComponent(o.plan_label || '')}&ct=${encodeURIComponent((o.content_type||'Family').toLowerCase())}">Renew this plan</a>
O
cat > "$T/a1_n" <<'O'
    <a class="za-btn" href="/checkout?s=${esc(o.server_slug || '')}&plan=${encodeURIComponent(o.plan_label || '')}&ct=${encodeURIComponent((o.content_type||'Family').toLowerCase())}&renew=${encodeURIComponent(o.ref || '')}">Renew this plan</a>
O

# ===== checkout: capture renewal at order creation =====
cat > "$T/c1_o" <<'O'
      const ref = await newRef();
      const r = await pool.query(
        `INSERT INTO orders (ref, customer_id, kind, server_id, plan_label, duration_days, price_amount, price_currency, content_type, status)
         VALUES ($1,$2,'new',$3,$4,$5,$6,'PKR',$7,'awaiting_payment') RETURNING id`,
        [ref, c.id, sv.id, plan.label, plan.days || null, pkr, (String(req.query.ct||'').toLowerCase()==='adult' ? 'Adult' : 'Family')]);
      res.redirect('/checkout/' + ref);
O
cat > "$T/c1_n" <<'O'
      const ref = await newRef();
      let _okind = 'new', _renewUser = null, _renewOf = null;
      try {
        const _rof = String(req.query.renew || '').trim();
        if (_rof) {
          const _ro = (await pool.query("SELECT ref, line_user FROM orders WHERE ref=$1 AND customer_id=$2 AND status='delivered'", [_rof, c.id])).rows[0];
          if (_ro && _ro.line_user) { _okind = 'renewal'; _renewUser = _ro.line_user; _renewOf = _ro.ref; }
        }
      } catch (e) {}
      const r = await pool.query(
        `INSERT INTO orders (ref, customer_id, kind, server_id, plan_label, duration_days, price_amount, price_currency, content_type, status, renew_username, renew_of)
         VALUES ($1,$2,$8,$3,$4,$5,$6,'PKR',$7,'awaiting_payment',$9,$10) RETURNING id`,
        [ref, c.id, sv.id, plan.label, plan.days || null, pkr, (String(req.query.ct||'').toLowerCase()==='adult' ? 'Adult' : 'Family'), _okind, _renewUser, _renewOf]);
      res.redirect('/checkout/' + ref);
O

# ===== atomic apply (all files or none) =====
node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
const jobs=[
  ['/opt/zayron/lib/gszApi.js', [['g1_o','g1_n'],['g2_o','g2_n']]],
  ['/opt/zayron/lib/orderDispatch.js', [['d1_o','d1_n']]],
  ['/opt/zayron/lib/orderWorker.js', [['w1_o','w1_n'],['w2_o','w2_n']]],
  ['/opt/zayron/routes/account.js', [['a1_o','a1_n']]],
  ['/opt/zayron/routes/checkout.js', [['c1_o','c1_n']]],
];
const out=[];
for(const [file,pairs] of jobs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} out.push([file,s]); }
for(const [file,s] of out){ fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
APPLY
[ $? -eq 0 ] || { echo "patch failed (nothing written across files) - reverting backups"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

for f in lib/gszApi.js lib/orderDispatch.js lib/orderWorker.js routes/account.js routes/checkout.js; do node --check "$f" || { echo "syntax error in $f - reverting"; revert; exit 1; }; done
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
pm2 restart zayron-orders >/dev/null 2>&1 || pm2 restart zayron-orders
HZ=000
for i in $(seq 1 15); do sleep 1; HZ=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:3500/" 2>/dev/null || echo 000); [ "$HZ" = "200" ] && break; done
OW=$(pm2 jlist 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const p=JSON.parse(d).find(x=>x.name==='zayron-orders');console.log((p&&p.pm2_env&&p.pm2_env.status)||'unknown');}catch(e){console.log('unknown');}});" 2>/dev/null)
echo "zayron / http=${HZ}   zayron-orders=${OW}"
[ "$HZ" = "200" ] || { echo "zayron not serving 200 - reverting"; revert; exit 1; }
echo "DONE: IPTV renewal live on zayron.tv (Renew button -> extend line via bridge, premium delivery + owner alert, fresh-line fallback). zayron=${HZ} worker=${OW}"
