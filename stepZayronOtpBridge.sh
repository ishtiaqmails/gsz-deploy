#!/usr/bin/env bash
# stepZayronOtpBridge — turn /opt/zayron-otp (zayron.tv's OTP sender) into a BRIDGE to the single shared Verification
# Bot (gszwabot). It keeps delivering queued codes AND now mirrors the REAL gszwabot connection — live status, the
# real connected number (447482794086), and the live QR image — into otp_status, and routes zayron's existing
# "Disconnect / scan a new number" button to gszwabot's /logout. Result: zayron.tv's /admin/otp panel shows the true
# shared bot (same session galaxyzayron uses); scanning or re-pairing from EITHER dashboard drives the one bot.
# No Baileys, no 2nd number. zayron's admin.js is NOT touched. Safe: backup + node --check + revert + live verify.
set -e
O=/opt/zayron-otp; cd "$O"
TS=$(date +%s); B="$O/.retired"; mkdir -p "$B"; cp index.js "$B/index.js.$TS"
revert(){ cp "$B/index.js.$TS" "$O/index.js"; pm2 restart zayron-otp >/dev/null 2>&1 || true; }

cat > "$O/index.js.new" <<'JS'
// Zayron OTP bridge — (1) delivers queued login codes through the SHARED Verification Bot (gszwabot) via
// /opt/zayron/lib/waSend.js, and (2) MIRRORS the real gszwabot connection (status, real number, live QR) into
// otp_status so the /admin/otp panel shows the true shared bot — the SAME session galaxyzayron.store uses.
// Scanning or disconnecting from either dashboard drives the one bot. No Baileys, no QR socket, no 2nd number.
require('dotenv').config();
const { Pool } = require('pg');
const http = require('http');
const https = require('https');
const { URL } = require('url');
const pool = new Pool(); // PG* from env

let QR = null; try { QR = require('qrcode'); } catch (e) { console.error('qrcode missing:', e.message); }

let waSend;
try { waSend = require('/opt/zayron/lib/waSend'); }
catch (e) { console.error('waSend unavailable:', e.message); waSend = { send: async () => ({ ok: false, error: 'wasend_missing' }) }; }

// gszwabot URL + secret live in /opt/zayron/.env (same place waSend reads them).
try { require('fs').readFileSync('/opt/zayron/.env', 'utf8').split('\n').forEach(function (l) { var m = l.match(/^(GSZ_WABOT_(?:URL|SECRET))=(.*)$/); if (m && !process.env[m[1]]) process.env[m[1]] = m[2].trim(); }); } catch (e) {}
const WABOT_SEND = process.env.GSZ_WABOT_URL || 'http://127.0.0.1:8095/send';
const WABOT_ORIGIN = (function () { try { const u = new URL(WABOT_SEND); return u.protocol + '//' + u.host; } catch (e) { return 'http://127.0.0.1:8095'; } })();
const WABOT_SECRET = process.env.GSZ_WABOT_SECRET || '';

function botReq(path, method) {
  return new Promise(function (resolve) {
    try {
      const u = new URL(WABOT_ORIGIN + path);
      const mod = u.protocol === 'https:' ? https : http;
      const req = mod.request({ hostname: u.hostname, port: u.port || (u.protocol === 'https:' ? 443 : 80), path: u.pathname, method: method || 'GET', headers: { 'x-wa-secret': WABOT_SECRET } }, function (res) {
        let b = ''; res.on('data', d => b += d); res.on('end', function () { try { resolve(JSON.parse(b || '{}')); } catch (e) { resolve(null); } });
      });
      req.on('error', function () { resolve(null); });
      req.setTimeout(4000, function () { try { req.destroy(); } catch (e) {} resolve(null); });
      req.end();
    } catch (e) { resolve(null); }
  });
}

async function setStatus(obj) {
  try {
    for (const k of Object.keys(obj)) {
      await pool.query(
        "INSERT INTO otp_status(k,v,updated_at) VALUES($1,$2,now()) ON CONFLICT (k) DO UPDATE SET v=$2, updated_at=now()",
        [k, String(obj[k] == null ? '' : obj[k])]);
    }
  } catch (e) { console.error('setStatus', e.message); }
}

// ---- mirror the REAL shared bot into otp_status (status / real number / live QR image) ----
let lastQrStr = null, lastQrDataUrl = '';
async function mirrorStatus() {
  const s = await botReq('/status', 'GET');
  if (!s || !s.ok) { await setStatus({ status: 'connecting', number: '', qr: '' }); return; }
  if (s.connected) {
    await setStatus({ status: 'open', number: String(s.number || '').replace(/[^0-9]/g, ''), qr: '' });
    lastQrStr = null; lastQrDataUrl = '';
  } else if (s.qr && QR) {
    if (s.qr !== lastQrStr) { try { lastQrDataUrl = await QR.toDataURL(s.qr, { margin: 1, width: 300 }); lastQrStr = s.qr; } catch (e) {} }
    await setStatus({ status: 'qr', number: '', qr: lastQrDataUrl || '' });
  } else {
    await setStatus({ status: 'connecting', number: '', qr: '' });
  }
}

// ---- zayron's "Disconnect / scan a new number" button (sets reset_requested=1) -> relogin the shared bot ----
async function checkReset() {
  try {
    const r = (await pool.query("SELECT v FROM otp_status WHERE k='reset_requested'")).rows[0];
    if (r && String(r.v) === '1') {
      await pool.query("INSERT INTO otp_status(k,v,updated_at) VALUES('reset_requested','0',now()) ON CONFLICT (k) DO UPDATE SET v='0', updated_at=now()");
      await botReq('/logout', 'POST');
      console.log('[otp] reset requested -> gszwabot /logout (fresh QR shows on both dashboards)');
    }
  } catch (e) { console.error('checkReset', e.message); }
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
  console.log('Zayron OTP bridge up — delivering codes + mirroring the shared Verification Bot (gszwabot)');
  mirrorStatus();
  setInterval(drain, 4000);
  setInterval(mirrorStatus, 3000);
  setInterval(checkReset, 2000);
})();
JS

node --check "$O/index.js.new" || { echo "new index.js syntax error - aborting, nothing changed"; rm -f "$O/index.js.new"; exit 1; }
mv "$O/index.js.new" "$O/index.js"
pm2 restart zayron-otp >/dev/null 2>&1 || pm2 restart zayron-otp

echo "waiting for the bridge to mirror the live bot..."
sleep 6
ST=$(pm2 jlist 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const p=JSON.parse(d).find(x=>x.name==='zayron-otp');console.log((p&&p.pm2_env&&p.pm2_env.status)||'unknown');}catch(e){console.log('unknown');}});" 2>/dev/null)
echo "zayron-otp pm2 status: ${ST}"
[ "$ST" = "online" ] || { echo "zayron-otp not online - reverting"; revert; exit 1; }

echo "--- otp_status now (should show the REAL shared bot) ---"
node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool();p.query(\"SELECT k,v,updated_at FROM otp_status WHERE k IN ('status','number','qr') ORDER BY k\").then(r=>{r.rows.forEach(x=>console.log('  '+x.k+' = '+(x.k==='qr'?('['+String(x.v||'').length+' chars]'):(x.v||'(empty)'))+'   @'+(x.updated_at?x.updated_at.toISOString().slice(11,19):'')));return p.end();}).catch(e=>{console.log('query ERR',e.message);process.exit(0);});" 2>&1 | tail -6
echo
echo "DONE: zayron-otp is now a bridge to the shared gszwabot. zayron.tv /admin/otp shows the real status/number/QR."
echo "If 'status = connecting' persists, the GSZ_WABOT_SECRET couldn't be read from /opt/zayron/.env — tell me and I'll wire it."
