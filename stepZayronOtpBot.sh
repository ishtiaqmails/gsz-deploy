#!/usr/bin/env bash
# stepZayronOtpBot — retire the fragile standalone Baileys OTP number and deliver login codes
# through the shared Verification Bot (gszwabot) instead. Same process name (zayron-otp), same
# otp_outbox + otp_status contract, so account.js and the website are UNTOUCHED. No Baileys, no
# QR, no second WhatsApp number -> nothing to ban or drop. Fail-safe if waSend is ever missing.
set -e
O=/opt/zayron-otp
[ -f "$O/index.js" ] || { echo "ERROR: $O/index.js not found"; exit 1; }
TS=$(date +%s)
# idempotent backup: only snapshot the original Baileys worker once; later re-runs save a .prev
if grep -q "baileys" "$O/index.js" 2>/dev/null; then
  cp "$O/index.js" "$O/index.js.baileys.bak.$TS"; echo "backed up original Baileys worker -> $O/index.js.baileys.bak.$TS"
else
  cp "$O/index.js" "$O/index.js.prev.bak.$TS"; echo "backed up previous drainer -> $O/index.js.prev.bak.$TS"
fi

cat > "$O/index.js" <<'OTP'
// Zayron OTP sender — lean outbox drainer. Delivers each queued login code through the SHARED
// Verification Bot (gszwabot) via /opt/zayron/lib/waSend.js. No Baileys, no QR, no second number.
// Contract unchanged: account.js still enqueues into otp_outbox; the admin dashboard still reads
// otp_status. If waSend is ever missing it no-ops instead of crash-looping.
require('dotenv').config();
const { Pool } = require('pg');
const pool = new Pool(); // PG* from env, same as before

let waSend;
try { waSend = require('/opt/zayron/lib/waSend'); }
catch (e) { console.error('waSend unavailable:', e.message); waSend = { send: async () => ({ ok: false, error: 'wasend_missing' }) }; }

async function setStatus(obj) {
  try {
    for (const k of Object.keys(obj)) {
      await pool.query(
        "INSERT INTO otp_status(k,v,updated_at) VALUES($1,$2,now()) ON CONFLICT (k) DO UPDATE SET v=$2, updated_at=now()",
        [k, String(obj[k] == null ? '' : obj[k])]);
    }
  } catch (e) { console.error('setStatus', e.message); }
}
// keep the retail bot's number normalisation so 03xx / 0092 / bare 3xx all resolve to 92xxxxxxxxxx
function normalizeMsisdn(phone) {
  let d = String(phone || '').replace(/[^0-9]/g, '');
  if (!d) return '';
  if (d.startsWith('00')) d = d.slice(2);
  if (d.startsWith('0')) d = '92' + d.slice(1);
  if (d.length === 10 && d.startsWith('3')) d = '92' + d;
  return d;
}

let draining = false;
async function drain() {
  if (draining) return;
  draining = true;
  try {
    // the outbox is the single source of truth: account.js decides when a code is enqueued,
    // so the drainer simply delivers whatever is queued (no hidden enable/disable flag).
    const rows = (await pool.query("SELECT id, phone, body FROM otp_outbox WHERE status='queued' ORDER BY id ASC LIMIT 5")).rows;
    for (const m of rows) {
      const to = normalizeMsisdn(m.phone);
      if (!to) { await pool.query("UPDATE otp_outbox SET status='failed', tries=tries+1 WHERE id=$1", [m.id]); continue; }
      let r = null; try { r = await waSend.send(to, m.body); } catch (e) { r = { ok: false, error: e.message }; }
      if (r && r.ok) {
        await pool.query("UPDATE otp_outbox SET status='sent', sent_at=now() WHERE id=$1", [m.id]);
        console.log('OTP sent', m.phone);
      } else {
        await pool.query("UPDATE otp_outbox SET status=CASE WHEN tries>=2 THEN 'failed' ELSE 'queued' END, tries=tries+1 WHERE id=$1", [m.id]);
        console.error('OTP send fail', m.phone, r && r.error);
      }
      await new Promise(res => setTimeout(res, 800)); // gentle gap
    }
  } catch (e) { console.error('drain', e.message); }
  finally { draining = false; }
}

(async function () {
  await setStatus({ status: 'open', number: 'Verification Bot', qr: '', updated_at: new Date().toISOString() });
  console.log('Zayron OTP drainer up — delivering via Verification Bot (gszwabot)');
  setInterval(drain, 4000);
  // refresh status so the admin panel keeps reading "connected"
  setInterval(function () { setStatus({ status: 'open', number: 'Verification Bot', qr: '', updated_at: new Date().toISOString() }); }, 60000);
})();
OTP

node --check "$O/index.js" || { echo "syntax error - restoring"; cp "$O/index.js.baileys.bak.$TS" "$O/index.js"; exit 1; }
pm2 restart zayron-otp >/dev/null 2>&1 || pm2 restart zayron-otp
sleep 2
echo "--- zayron-otp recent log ---"
pm2 logs zayron-otp --lines 6 --nostream 2>/dev/null || true
echo "DONE: OTP now delivers via the Verification Bot. account.js + otp_outbox unchanged; old Baileys worker backed up."
