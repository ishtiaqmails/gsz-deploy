#!/usr/bin/env bash
# stepZayronDeliveryMsg — premium delivery message on zayron.tv (like galaxyzayron). Adds lib/deliveryMsg.js (the same
# composer), passes the reseller bot's raw `fields` through orderDispatch.poll so Players + all credential lines
# survive, and rewrites orderWorker.notifyDelivered to render Product Name, Order No, Date, Plan, Login Credentials,
# and Players (players come from the reseller bot admin, same as DNS). Product name from zayron's server catalog.
# Safe: backup + single-match + revert + node --check + health loop on zayron / (==200) + worker online.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp lib/orderDispatch.js "$B/"; cp lib/orderWorker.js "$B/"
revert(){ cp "$B/orderDispatch.js" lib/orderDispatch.js; cp "$B/orderWorker.js" lib/orderWorker.js; rm -f lib/deliveryMsg.js; pm2 restart zayron >/dev/null 2>&1 || true; pm2 restart zayron-orders >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# ---------- new composer ----------
cat > lib/deliveryMsg.js <<'DMJS'
'use strict';
/* Premium delivery composer (zayron.tv) — mirrors galaxyzayron. Turns the reseller bot's structured `fields`
   + the order into a premium WhatsApp message. Pure + fail-safe. */
function esc(v) { return String(v == null ? '' : v).trim(); }
const RULE = '━━━━━━━━━━━━━━';
function sectionTitle(t) { return '━━━  *' + t + '*  ━━━'; }
function fmtDate(d) {
  try { return new Date(d || Date.now()).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }); }
  catch (e) { return ''; }
}
function compose(order, fields, opts) {
  order = order || {}; fields = fields || {}; opts = opts || {};
  const dt = esc(fields.delivery_type) || 'credentials';
  const site = esc(opts.siteName) || 'Zayron';
  const sales = String(opts.salesNumber || '').replace(/[^0-9]/g, '');
  const product = esc(fields.product) || esc(order.product_name);
  const plan = esc(fields.plan) || esc(order.plan_label);
  const expiry = esc(fields.expiry);
  const orderNo = esc(order.order_no);
  const isInvite = dt === 'vendor_invite';
  const isTrial = !!opts.trial;
  const durationLabel = esc(opts.durationLabel);
  const versionLabel = esc(opts.versionLabel);
  const L = [];
  L.push(RULE);
  L.push(isTrial ? '🎁 *FREE TRIAL READY*' : (isInvite ? '✅ *INVITE SENT*' : '✅ *ORDER DELIVERED*'));
  L.push('_' + site + '_');
  L.push(RULE);
  L.push('');
  if (product) L.push('📦 *' + product + '*');
  if (isTrial) {
    L.push('🎯 Trial  ·  ' + (durationLabel || plan || 'Trial'));
    if (expiry) L.push('📆 Expires  ·  ' + expiry);
  } else {
    if (orderNo) L.push('🧾 Order  ·  ' + orderNo);
    L.push('📅 ' + (isInvite ? 'Sent' : 'Purchased') + '  ·  ' + fmtDate(order.created_at));
    if (plan) L.push('⏳ Plan  ·  ' + plan + (versionLabel ? ' — ' + versionLabel : ''));
    else if (versionLabel) L.push('⏳ Plan  ·  ' + versionLabel);
    if (expiry) L.push('📆 Expires  ·  ' + expiry);
  }
  L.push('');
  const details = Array.isArray(fields.details) ? fields.details.filter(function (d) {
    const lb = esc(d && d.label).toLowerCase();
    return esc(d && d.value) && lb !== 'support';
  }) : [];
  if (dt === 'vendor_invite') {
    const boxes = (fields.invite && Array.isArray(fields.invite.inboxes)) ? fields.invite.inboxes.filter(Boolean) : [];
    L.push(sectionTitle('CHECK YOUR INBOX'));
    boxes.forEach(function (b) { L.push('📧 ' + esc(b)); });
    L.push('');
    L.push('Open the invite from your inbox — check spam/junk too.');
    L.push(RULE);
  } else if (dt === 'player_activation') {
    const acts = Array.isArray(fields.activations) ? fields.activations : [];
    L.push(sectionTitle('ACTIVATED'));
    acts.forEach(function (a) {
      const mac = esc(a && a.mac); const pl = esc(a && a.plan); const ex = esc(a && a.expiry);
      L.push('• ' + mac + (pl ? ' — ' + pl : '') + (ex ? ' (exp ' + ex + ')' : ''));
    });
    L.push(RULE);
  } else {
    L.push(sectionTitle(dt === 'iptv' ? 'YOUR LINE' : 'YOUR LOGIN'));
    details.forEach(function (d) { L.push(esc(d.label) + ':  ' + esc(d.value)); });
    L.push(RULE);
    if (dt === 'iptv') {
      const players = Array.isArray(fields.players) ? fields.players : [];
      if (players.length) {
        L.push('');
        L.push('📺 *WATCH ON*');
        players.forEach(function (p) { L.push('• ' + esc(p && p.platform) + ' — ' + esc(p && p.url)); });
        L.push(RULE);
      }
    }
  }
  L.push('');
  if (isTrial) {
    const up = esc(opts.siteUrl);
    if (up) L.push('🚀 Upgrade to full access: ' + up);
    if (sales) L.push('💬 Questions? wa.me/' + sales);
    L.push('Thank you for trying us.');
  } else {
    if (sales) L.push('💬 Need help? wa.me/' + sales);
    L.push('Thank you for choosing us.');
  }
  const main = L.join('\n');
  let credentials = '';
  if (details.length) {
    const credLines = [];
    if (versionLabel) credLines.push('Version: ' + versionLabel);
    details.forEach(function (d) { credLines.push(esc(d.label) + ': ' + esc(d.value)); });
    if (expiry) credLines.push('Expiry: ' + expiry);
    credentials = credLines.join('\n');
  }
  let instr = opts.instructions;
  if (typeof instr === 'string') instr = instr.split(/\r?\n/);
  instr = Array.isArray(instr) ? instr.map(esc).filter(Boolean) : [];
  const warr = (dt === 'iptv') ? '' : (esc(fields.warranty) || (Number(fields.warranty_days) > 0 ? (Number(fields.warranty_days) + ' Days Warranty') : '') || esc(opts.warranty));
  let followup = '';
  if (instr.length || warr) {
    const F = [];
    F.push(RULE);
    F.push('📋 *' + (product || 'Your order') + '*');
    F.push('_' + (instr.length && warr ? 'Instructions & Warranty' : (warr ? 'Warranty' : 'Instructions')) + '_');
    F.push(RULE);
    if (instr.length) { instr.forEach(function (x) { F.push('• ' + x); }); }
    if (warr) { F.push(''); F.push('🛡️ *Warranty:* ' + warr); }
    if (sales) { F.push(''); F.push('💬 Any issue? wa.me/' + sales); }
    followup = F.join('\n');
  }
  return { main: main, followup: followup, credentials: credentials };
}
module.exports = { compose };
DMJS
node --check lib/deliveryMsg.js || { echo "deliveryMsg.js syntax error - aborting"; rm -f lib/deliveryMsg.js; rm -rf "$T"; exit 1; }

# ---------- edit 1: orderDispatch.poll passes raw fields ----------
cat > "$T/d_o" <<'O'
    if (st.status === 'delivered') return { status: 'done', result: extractLine(st.fields), card: st.delivered_credentials || '' };
O
cat > "$T/d_n" <<'O'
    if (st.status === 'delivered') return { status: 'done', result: extractLine(st.fields), fields: st.fields || {}, card: st.delivered_credentials || '' };
O

# ---------- edit 2: runCollect passes p.fields into notifyDelivered ----------
cat > "$T/r_o" <<'O'
        try { await notifyDelivered(o, r, url, exp); } catch (e) { try { log.log('[deliver-notify-fail]', o.ref, e.message); } catch (_) {} }
O
cat > "$T/r_n" <<'O'
        try { await notifyDelivered(o, r, url, exp, p.fields); } catch (e) { try { log.log('[deliver-notify-fail]', o.ref, e.message); } catch (_) {} }
O

# ---------- edit 3: notifyDelivered -> premium composer ----------
cat > "$T/n_o" <<'O'
  async function notifyDelivered(o, r, url, exp) {
    if (!o || !o.customer_id) return;
    const c = (await pool.query("SELECT phone, name FROM customers WHERE id=$1", [o.customer_id])).rows[0];
    if (!c || !c.phone) return;
    const name = String(c.name || '').trim();
    const user = (r && r.username) || o.line_user || '';
    const pass = (r && r.password) || o.line_pass || '';
    const link = url || o.line_url || '';
    const expTxt = exp ? new Date(exp).toISOString().slice(0, 10) : '';
    const L = [];
    L.push(name ? ('Hi ' + name + ',') : 'Hi,');
    L.push('Your Zayron order ' + o.ref + ' is ready.');
    if (o.plan_label) L.push('Plan: ' + o.plan_label);
    L.push('');
    if (link) L.push('URL: ' + link);
    if (user) L.push('Username: ' + user);
    if (pass) L.push('Password: ' + pass);
    if (expTxt) L.push('Expires: ' + expTxt);
    L.push('');
    L.push('You can also view this anytime in your account on zayron.tv');
    await waSend.send(c.phone, L.join('\n'));
  }
O
cat > "$T/n_n" <<'O'
  async function notifyDelivered(o, r, url, exp, botFields) {
    if (!o || !o.customer_id) return;
    const c = (await pool.query("SELECT phone, name FROM customers WHERE id=$1", [o.customer_id])).rows[0];
    if (!c || !c.phone) return;
    const deliveryMsg = require('./deliveryMsg');
    let productName = (botFields && botFields.product) ? String(botFields.product) : '';
    try { if (o.server_id) { const sv = (await pool.query("SELECT name FROM servers WHERE id=$1", [o.server_id])).rows[0]; if (sv && sv.name) productName = sv.name; } } catch (e) {}
    const fields = (botFields && typeof botFields === 'object') ? Object.assign({}, botFields) : {};
    if (!Array.isArray(fields.details) || !fields.details.length) {
      const det = [];
      const user = (r && r.username) || o.line_user || '';
      const pass = (r && r.password) || o.line_pass || '';
      const link = url || o.line_url || '';
      if (user) det.push({ label: 'Username', value: user });
      if (pass) det.push({ label: 'Password', value: pass });
      if (link) det.push({ label: 'DNS', value: link });
      fields.details = det;
    }
    if (!fields.delivery_type) fields.delivery_type = 'iptv';
    if (!fields.expiry && exp) { try { fields.expiry = new Date(exp).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }); } catch (e) {} }
    let sales = ''; try { const sr = (await pool.query("SELECT value FROM settings WHERE key='whatsapp_number'")).rows[0]; sales = sr ? String(sr.value).replace(/[^0-9]/g, '') : ''; } catch (e) {}
    const order = { order_no: o.ref, created_at: o.created_at, product_name: productName, plan_label: o.plan_label };
    let text = '';
    try { const m = deliveryMsg.compose(order, fields, { siteName: 'Zayron', salesNumber: sales, siteUrl: 'zayron.tv', versionLabel: (o.content_type || '') }); text = (m && m.main) || ''; } catch (e) {}
    if (!text) {
      const nm = String(c.name || '').trim();
      const LL = [nm ? ('Hi ' + nm + ',') : 'Hi,', 'Your Zayron order ' + o.ref + ' is ready.'];
      if (r && r.username) LL.push('Username: ' + r.username);
      if (r && r.password) LL.push('Password: ' + r.password);
      if (url || o.line_url) LL.push('DNS: ' + (url || o.line_url));
      text = LL.join('\n');
    }
    await waSend.send(c.phone, text);
  }
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('/opt/zayron/lib/orderDispatch.js', [['d_o','d_n']]);
patch('/opt/zayron/lib/orderWorker.js', [['r_o','r_n'],['n_o','n_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check lib/orderDispatch.js || { echo "orderDispatch syntax error - reverting"; revert; exit 1; }
node --check lib/orderWorker.js || { echo "orderWorker syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
pm2 restart zayron-orders >/dev/null 2>&1 || pm2 restart zayron-orders
HZ=000
for i in $(seq 1 15); do sleep 1; HZ=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:3500/" 2>/dev/null || echo 000); [ "$HZ" = "200" ] && break; done
OW=$(pm2 jlist 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const p=JSON.parse(d).find(x=>x.name==='zayron-orders');console.log((p&&p.pm2_env&&p.pm2_env.status)||'unknown');}catch(e){console.log('unknown');}});" 2>/dev/null)
echo "zayron / http=${HZ}   zayron-orders=${OW}"
[ "$HZ" = "200" ] || { echo "zayron not serving 200 - reverting"; revert; exit 1; }
echo "DONE: zayron.tv delivery message is now premium (Product, Order, Date, Plan, Credentials, Players from the reseller bot). zayron=${HZ} worker=${OW}"
