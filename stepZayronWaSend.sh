#!/usr/bin/env bash
# stepZayronWaSend — add zayron's Verification-Bot (gszwabot) sender: lib/waSend.js.
# POSTs {to,text} to gszwabot /send (port 8095, same box). Matches GSZ's postSend.
# Only ADDS a file (nothing wired yet) -> no restart, zero risk to the live site.
# Optional env (only if gszwabot ever enforces it): GSZ_WABOT_URL, GSZ_WABOT_SECRET.
set -e
Z=/opt/zayron; cd "$Z"

cat > lib/waSend.js <<'WASEND'
'use strict';
/* lib/waSend.js — send a WhatsApp message through the Verification Bot (gszwabot), the SAME
   bot galaxyzayron.store uses. Direct POST to gszwabot /send (port 8095, localhost). Never the
   reseller bot. Env (optional): GSZ_WABOT_URL (default http://127.0.0.1:8095/send), GSZ_WABOT_SECRET. */
const http = require('http');
const https = require('https');
const { URL } = require('url');

// env fallback so any zayron process can send, even if it didn't load .env
if (!process.env.GSZ_WABOT_URL || !process.env.GSZ_WABOT_SECRET) {
  try { require('fs').readFileSync(require('path').join(__dirname, '..', '.env'), 'utf8').split('\n').forEach(function (l) { var m = l.match(/^(GSZ_WABOT_(?:URL|SECRET))=(.*)$/); if (m && !process.env[m[1]]) process.env[m[1]] = m[2].trim(); }); } catch (e) {}
}
function cfg() { return { url: process.env.GSZ_WABOT_URL || 'http://127.0.0.1:8095/send', secret: process.env.GSZ_WABOT_SECRET || '' }; }

// send(to, text) -> Promise<{ok, status, id?, error?}>. Never throws into callers.
function send(to, text) {
  return new Promise(function (resolve) {
    try {
      const c = cfg();
      const digits = String(to || '').replace(/[^0-9]/g, '');
      if (!digits || !String(text || '').trim()) return resolve({ ok: false, status: 0, error: 'to+text required' });
      const u = new URL(c.url);
      const data = Buffer.from(JSON.stringify({ to: digits, text: String(text) }));
      const mod = u.protocol === 'https:' ? https : http;
      const headers = { 'Content-Type': 'application/json', 'Content-Length': data.length };
      if (c.secret) headers['X-WA-Secret'] = c.secret;
      const r = mod.request({ hostname: u.hostname, port: u.port || (u.protocol === 'https:' ? 443 : 80), path: u.pathname + u.search, method: 'POST', headers }, function (res) {
        let b = ''; res.on('data', d => b += d); res.on('end', function () {
          let j = null; try { j = JSON.parse(b); } catch (e) {}
          resolve({ ok: !!(j && j.ok), status: res.statusCode, id: j && j.id, error: j && j.error });
        });
      });
      r.on('error', e => resolve({ ok: false, status: 0, error: e.message }));
      r.setTimeout(12000, function () { try { r.destroy(); } catch (e) {} resolve({ ok: false, status: 0, error: 'timeout' }); });
      r.write(data); r.end();
    } catch (e) { resolve({ ok: false, status: 0, error: e.message }); }
  });
}

module.exports = { send };
WASEND

node --check lib/waSend.js || { echo "syntax error - removing"; rm -f lib/waSend.js; exit 1; }
echo "DONE: lib/waSend.js added (not wired yet — no restart)."
