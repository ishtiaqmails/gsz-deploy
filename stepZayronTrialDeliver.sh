#!/usr/bin/env bash
# stepZayronTrialDeliver — when a web trial becomes READY, send the login to the customer's WhatsApp
# via the Verification Bot (same otp_outbox pipeline that already works). Fires exactly once (gated on
# the status-flip rowCount). Safe: backup, single-match anchor + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp routes/trial.js "$B/trial.js.bak"
revert(){ cp "$B/trial.js.bak" routes/trial.js; pm2 restart zayron >/dev/null 2>&1 || true; }

node - <<'APPLY'
const fs = require('fs'); const F = 'routes/trial.js';
let s = fs.readFileSync(F, 'utf8');
const o = `          await pool.query(
            "UPDATE trials SET status='ready', line_user=$1, line_pass=$2, line_url=$3, ready_at=now(), expires_at=now() + ($4 || ' hours')::interval WHERE id=$5",
            [u, pw, url, String(hrs), t.id]);
          return res.json({ ok: true, status: 'ready', user: u, pass: pw, url, formatted: p.result.formatted || null, expires_at: new Date(Date.now() + hrs*3600*1000).toISOString() });`;
const n = `          const _flip = await pool.query(
            "UPDATE trials SET status='ready', line_user=$1, line_pass=$2, line_url=$3, ready_at=now(), expires_at=now() + ($4 || ' hours')::interval WHERE id=$5 AND status<>'ready'",
            [u, pw, url, String(hrs), t.id]);
          if (_flip.rowCount && t.phone) {
            try {
              let _snm = 'your server';
              try { const _pd = await getPublicData(); const _sv = (_pd.servers || []).find(x => x.id === t.server_id); if (_sv && _sv.n) _snm = _sv.n; } catch (e) {}
              const _nl = String.fromCharCode(10);
              const _L = ['Your Zayron free trial is ready.', '', 'Server: ' + _snm];
              if (u) _L.push('Username: ' + u);
              if (pw) _L.push('Password: ' + pw);
              if (url) _L.push('URL: ' + url);
              _L.push('', 'Valid for ' + hrs + ' hours.');
              await pool.query("INSERT INTO otp_outbox (phone, body, status) VALUES ($1,$2,'queued')", [t.phone, _L.join(_nl)]);
            } catch (e) {}
          }
          return res.json({ ok: true, status: 'ready', user: u, pass: pw, url, formatted: p.result.formatted || null, expires_at: new Date(Date.now() + hrs*3600*1000).toISOString() });`;
const c = s.split(o).length - 1;
if (c !== 1) { console.error('ANCHOR x' + c); process.exit(5); }
fs.writeFileSync(F, s.split(o).join(n));
console.log('trial.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed"; exit 1; }

node --check routes/trial.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: ready trials now WhatsApp the login to the customer (once). healthz=200"
