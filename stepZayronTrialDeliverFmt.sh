#!/usr/bin/env bash
# stepZayronTrialDeliverFmt — send the bot's OWN house-formatted block (galaxyzayron format) to the
# customer's WhatsApp verbatim, normalise any brand website to www.zayron.tv, keep clean lines only as
# a fallback. Safe: backup, single-match anchor + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp routes/trial.js "$B/trial.js.bak"
revert(){ cp "$B/trial.js.bak" routes/trial.js; pm2 restart zayron >/dev/null 2>&1 || true; }

node - <<'APPLY'
const fs = require('fs'); const F = 'routes/trial.js';
let s = fs.readFileSync(F, 'utf8');
const o = `          if (_flip.rowCount && t.phone) {
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
          }`;
const n = `          if (_flip.rowCount && t.phone) {
            try {
              const _nl = String.fromCharCode(10);
              // prefer the bot's own house-formatted delivery block (same as galaxyzayron)
              let _body = (p.result && p.result.formatted && String(p.result.formatted).trim()) ? String(p.result.formatted).trim() : '';
              if (!_body) {
                let _snm = 'your server';
                try { const _pd = await getPublicData(); const _sv = (_pd.servers || []).find(x => x.id === t.server_id); if (_sv && _sv.n) _snm = _sv.n; } catch (e) {}
                const _L = ['Your Zayron free trial is ready.', '', 'Server: ' + _snm];
                if (u) _L.push('Username: ' + u);
                if (pw) _L.push('Password: ' + pw);
                if (url) _L.push('URL: ' + url);
                _L.push('', 'Valid for ' + hrs + ' hours.');
                _body = _L.join(_nl);
              }
              // zayron house website on every delivery
              _body = _body.replace(/https?:\\/\\/(www\\.)?(galaxyzayron|galaxytools|galaxy-?subz)[^\\s]*/gi, 'www.zayron.tv');
              if (!/zayron\\.tv/i.test(_body)) _body = _body + _nl + _nl + 'www.zayron.tv';
              await pool.query("INSERT INTO otp_outbox (phone, body, status) VALUES ($1,$2,'queued')", [t.phone, _body]);
            } catch (e) {}
          }`;
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
echo "DONE: trial WhatsApp now uses the galaxyzayron house format, website www.zayron.tv. healthz=200"
