#!/usr/bin/env bash
# stepZayronDeliverMsg — when an order flips to 'delivered', WhatsApp the customer their line
# details through the shared Verification Bot (gszwabot), via lib/waSend.js. Fail-safe: a notify
# error never blocks or reverts delivery. No double-send (status leaves 'provisioning' once).
# Quiet in Manual mode because no online orders exist there. checkout + UI unchanged.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zdm; rm -rf "$W"; mkdir -p "$W/p"
cp lib/orderWorker.js "$W/orderWorker.js.bak"
revert(){ cp "$W/orderWorker.js.bak" lib/orderWorker.js; }

# ---- require waSend ----
cat > "$W/p/o1" <<'OLD'
const gszApi = require('./gszApi');
OLD
cat > "$W/p/n1" <<'NEW'
const gszApi = require('./gszApi');
const waSend = require('./waSend');
NEW

# ---- notifyDelivered() inserted before runCollect ----
cat > "$W/p/o2" <<'OLD'
  // Read results back from the bot and finish the order.
OLD
cat > "$W/p/n2" <<'NEW'
  // WhatsApp the finished line to the customer via the Verification Bot. Never blocks delivery.
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

  // Read results back from the bot and finish the order.
NEW

# ---- call notifyDelivered right after delivery is recorded ----
cat > "$W/p/o3" <<'OLD'
        log.log('[delivered]', o.ref, r.username || '');
OLD
cat > "$W/p/n3" <<'NEW'
        log.log('[delivered]', o.ref, r.username || '');
        try { await notifyDelivered(o, r, url, exp); } catch (e) { try { log.log('[deliver-notify-fail]', o.ref, e.message); } catch (_) {} }
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zdm/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+'] in '+file); process.exit(5);} fs.writeFileSync(file, s.replace(o,function(){return n;})); }
rep('lib/orderWorker.js','o1','n1');
rep('lib/orderWorker.js','o2','n2');
rep('lib/orderWorker.js','o3','n3');
console.log('PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
node --check lib/orderWorker.js || { echo "syntax error - reverting"; revert; exit 1; }

pm2 restart zayron-orders >/dev/null 2>&1 || pm2 restart zayron-orders
echo "DONE: delivery now also WhatsApps the customer their line via the Verification Bot."
