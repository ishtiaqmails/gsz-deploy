#!/usr/bin/env bash
# gsz-sweep29 : trial->paid delivery fix. When a bot RENEW fails (e.g. a non-renewable
# trial line -> order_not_found), fall back to creating a FRESH line instead of failing
# the paid order. Fresh/new orders and successful renews are unaffected.
# Safe: backup, 1-match guard, node --check, auto-revert on error.
set -e
cd /opt/gsz
F=routes/checkout.js
cp "$F" /opt/gsz/.gsz-s29-checkout.bak

cat > /tmp/gsz_checkout_patch.js <<'PATCH'
const fs=require('fs');
const f='/opt/gsz/routes/checkout.js';
let s=fs.readFileSync(f,'utf8');
if(s.indexOf('_renewOk')!==-1){ console.error('ALREADY PATCHED'); process.exit(3); }
const OLD = `      if (_ofR.renew_line) {
        try {
          const _rl = _ofR.renew_line;
          const rr = await botapi.renew({
            renewal_id: 'ren-' + o.order_no,
            sku: o.bot_sku,
            username: _rl.username,
            raw: _rl.raw || '',
            plan_key: o.bot_plan_key,
            version: _rl.version || 'family',
            whatsapp: String(o.whatsapp || '').replace(/[^0-9]/g, '')
          });
          if (rr && rr.ok === false) {
            await pool.query("UPDATE orders SET status='failed', claim_result=$1 WHERE id=$2", [('renew_' + (rr.reason || 'err')).slice(0, 80), o.id]);
            return;
          }
          await pool.query("UPDATE orders SET status='delivering', bot_order_id=$1 WHERE id=$2", [String((rr && rr.request_id) || ('ren-' + o.order_no)), o.id]);
          await pollOnce(o.order_no);
        } catch (e) {
          await pool.query('UPDATE orders SET claim_result=$1 WHERE id=$2', [('renew_err:' + e.message).slice(0, 80), o.id]);
        }
        return;
      }`;
const NEW = `      if (_ofR.renew_line) {
        let _renewOk = false;
        try {
          const _rl = _ofR.renew_line;
          const rr = await botapi.renew({
            renewal_id: 'ren-' + o.order_no,
            sku: o.bot_sku,
            username: _rl.username,
            raw: _rl.raw || '',
            plan_key: o.bot_plan_key,
            version: _rl.version || 'family',
            whatsapp: String(o.whatsapp || '').replace(/[^0-9]/g, '')
          });
          if (!(rr && rr.ok === false)) {
            await pool.query("UPDATE orders SET status='delivering', bot_order_id=$1 WHERE id=$2", [String((rr && rr.request_id) || ('ren-' + o.order_no)), o.id]);
            await pollOnce(o.order_no);
            _renewOk = true;
          }
        } catch (e) {
          await pool.query('UPDATE orders SET claim_result=$1 WHERE id=$2', [('renew_err:' + e.message).slice(0, 80), o.id]);
        }
        if (_renewOk) return;
        // renew could not extend that line (trial not renewable / order_not_found):
        // drop the renew hint and create a fresh line, so a paid customer is never left undelivered.
        try { if (o.fields && typeof o.fields === 'object') { delete o.fields.renew_line; } } catch (e) {}
      }`;
const n=s.split(OLD).length-1;
if(n!==1){ console.error('OLD match count != 1 (got '+n+')'); process.exit(4); }
s=s.replace(OLD,NEW);
fs.writeFileSync(f,s);
console.log('PATCHED OK');
PATCH

node /tmp/gsz_checkout_patch.js || { echo "patch failed - reverting"; cp /opt/gsz/.gsz-s29-checkout.bak "$F"; exit 1; }
node --check "$F" || { echo "syntax error - reverting"; cp /opt/gsz/.gsz-s29-checkout.bak "$F"; exit 1; }

pm2 restart gsz
echo "DONE: renew failures now fall back to a fresh line."
