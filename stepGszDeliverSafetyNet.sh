#!/usr/bin/env bash
# stepGszDeliverSafetyNet — additive delivery safety net for galaxyzayron. Adds rescueStuck() on a 60s timer:
# finds orders stuck in 'delivering' > 3 min, tries EVERY status endpoint (order/renew/activate) so a
# mis-routed poll can't orphan an order, delivers via the same emailOrder+notifyOrder path, and after ~12 min
# sends a ONE-TIME owner alert on the bot. Does not change the existing drainer/pollOnce happy path.
# One anchored insert in routes/checkout.js. Safe: backup, single-match + auto-revert, node --check, health loop on '/'.
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp routes/checkout.js "$B/checkout.js.bak"
revert(){ cp "$B/checkout.js.bak" routes/checkout.js; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/o" <<'O'
  if (drainer.unref) drainer.unref();
O
cat > "$T/n" <<'O'
  if (drainer.unref) drainer.unref();

  // Safety net: rescue orders stuck in 'delivering' that the normal poll didn't finish. Tries EVERY status
  // endpoint (submit/renew/activate) so a mis-routed poll can't orphan an order, delivers via the same
  // notify path, and alerts the owner ONCE if an order genuinely can't auto-complete. Gentle: once a minute,
  // only on orders older than 3 min (0 bot calls when nothing is stuck).
  async function rescueStuck() {
    try {
      if (!botapi.configured()) return;
      const rows = (await pool.query(
        "SELECT id, order_no, bot_order_id, created_at FROM orders " +
        "WHERE status='delivering' AND created_at < now() - interval '3 minutes' " +
        "AND created_at > now() - interval '2 days' ORDER BY id DESC LIMIT 20")).rows;
      for (const o of rows) {
        let creds = '', done = false;
        const tries = [function () { return botapi.orderStatus(o.order_no); }];
        if (o.bot_order_id) {
          tries.push(function () { return botapi.renewStatus(o.bot_order_id); });
          tries.push(function () { return botapi.activateStatus(o.bot_order_id); });
        }
        for (let i = 0; i < tries.length && !done; i++) {
          try {
            const r = await tries[i]();
            if (r && (r.status === 'delivered' || r.status === 'done')) {
              creds = r.delivered_credentials || r.credentials || (r.new_expires_at ? ('Renewed — new expiry: ' + r.new_expires_at) : '');
              done = true;
            }
          } catch (e) { /* try the next endpoint */ }
        }
        if (done) {
          const upd = await pool.query(
            "UPDATE orders SET status='delivered', delivered_credentials=COALESCE(NULLIF($1,''), delivered_credentials), delivered_at=now() WHERE id=$2 AND status='delivering' RETURNING id",
            [creds, o.id]);
          if (upd.rows.length) {
            const full = (await pool.query('SELECT * FROM orders WHERE id=$1', [o.id])).rows[0];
            try { await emailOrder(full, 'delivered'); } catch (e) {}
            notifyOrder(full, 'delivered').catch(function () {});
          }
        } else {
          const ageMin = (Date.now() - new Date(o.created_at).getTime()) / 60000;
          if (ageMin > 12) {
            try {
              const claim = await pool.query("UPDATE orders SET owner_alerts = COALESCE(owner_alerts,'') || 'stuck,' WHERE id=$1 AND COALESCE(owner_alerts,'') NOT LIKE '%stuck,%' RETURNING id", [o.id]);
              if (claim.rows.length) {
                const f = (await pool.query('SELECT order_no, product_name, plan_label, whatsapp, amount_display, amount_pkr FROM orders WHERE id=$1', [o.id])).rows[0] || {};
                const amt = f.amount_display || ('Rs ' + Number(f.amount_pkr || 0).toLocaleString('en-US'));
                const msg = 'Order needs manual delivery\n\nOrder: ' + (f.order_no || '') + '\nProduct: ' + (f.product_name || '') + (f.plan_label ? (' - ' + f.plan_label) : '') + '\nWhatsApp: ' + (f.whatsapp || '-') + '\nAmount: ' + amt + '\n\nStuck in delivering for ~' + Math.round(ageMin) + ' min. Please deliver it from the admin dashboard.';
                await botapi.notify({ event: 'stuck', title: 'Order stuck - manual delivery needed', message: msg, text: msg, ref: f.order_no, order_no: f.order_no, status: 'stuck', product: f.product_name, plan: f.plan_label, whatsapp: f.whatsapp, at: new Date().toISOString() });
              }
            } catch (e) {}
          }
        }
      }
    } catch (e) { /* best-effort */ }
  }
  const rescuer = setInterval(function () { rescueStuck().catch(function () {}); }, 60000);
  if (rescuer.unref) rescuer.unref();
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('routes/checkout.js','utf8'); const O=rd('o'), N=rd('n'); const c=s.split(O).length-1;
if(c!==1){ console.error('ANCHOR x'+c); process.exit(5); }
fs.writeFileSync('routes/checkout.js', s.split(O).join(N)); console.log('routes/checkout.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/checkout.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 after restart - reverting"; revert; exit 1; }
echo "DONE: delivery safety net live (rescueStuck every 60s; owner alert after ~12 min). gsz http=${HC}"
