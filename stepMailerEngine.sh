#!/usr/bin/env bash
# Multi-provider mail engine. Keeps {configured,send}; adds refresh/activeProvider/sendWith.
cd /opt/gsz
f=/opt/gsz/lib/mailer.js
bak="$f.bak.$(date +%s)"
cp "$f" "$bak"
cat > "$f" <<'EOF'
'use strict';
/* GSZ email engine — multi-provider.
   Active provider comes from the email_providers table (managed at /admin/email).
   Env Brevo is the fallback. Sends over HTTPS APIs (host blocks SMTP ports).
   Public interface unchanged: configured(), send(to,subject,html,attachments).
   Extra: refresh(), activeProvider(), sendWith(provider, to, subject, html, att). */
const https = require('https');

let _pool = null;
function pool() {
  if (_pool) return _pool;
  try {
    try { require('dotenv').config({ path: '/opt/gsz/.env' }); } catch (e) {}
    const { Pool } = require('/opt/gsz/node_modules/pg');
    _pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS, max: 2 });
  } catch (e) { _pool = null; }
  return _pool;
}

function parseFrom(s) {
  s = String(s || '').trim();
  const m = s.match(/^\s*(.*?)\s*<\s*([^>]+)\s*>\s*$/);
  if (m) {
    const name = (m[1] || '').replace(/^"|"$/g, '').trim();
    return { name: name || 'Galaxy Subz x Zayron', email: m[2].trim() };
  }
  return { name: 'Galaxy Subz x Zayron', email: s };
}

function envProvider() {
  const key = process.env.BREVO_API_KEY || '';
  const fr = parseFrom(process.env.GSZ_SMTP_FROM || process.env.GSZ_MAIL_FROM || '');
  if (!key || !fr.email) return null;
  return { id: 0, provider: 'brevo', api_key: key, from_name: fr.name, from_email: fr.email, region: '' };
}

async function activeProvider() {
  try {
    const p = pool();
    if (p) {
      const r = await p.query("SELECT id, provider, api_key, from_name, from_email, region FROM email_providers WHERE is_active=true ORDER BY updated_at DESC, id DESC LIMIT 1");
      const row = r.rows[0];
      if (row && row.api_key && row.from_email) return row;
    }
  } catch (e) {}
  return envProvider();
}

let _ready = !!envProvider();
async function refresh() { try { _ready = !!(await activeProvider()); } catch (e) {} return _ready; }
function configured() { return _ready; }

function b64(c) { return Buffer.isBuffer(c) ? c.toString('base64') : Buffer.from(String(c || ''), 'utf8').toString('base64'); }

function httpsJson(o, bodyObj) {
  return new Promise((resolve, reject) => {
    const data = Buffer.from(JSON.stringify(bodyObj));
    const headers = Object.assign({ 'content-type': 'application/json', 'accept': 'application/json', 'content-length': data.length }, o.headers || {});
    const req = https.request({ method: 'POST', hostname: o.hostname, path: o.path, headers: headers }, res => {
      let buf = ''; res.setEncoding('utf8');
      res.on('data', d => { buf += d; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          let id = null;
          try { const j = JSON.parse(buf); id = j.messageId || j.id || (j.data && j.data[0] && (j.data[0].messageId || j.data[0].id)) || null; } catch (e) {}
          resolve({ ok: true, id: id });
        } else {
          const err = new Error(o.label + '_http_' + res.statusCode + ': ' + String(buf).slice(0, 300));
          console.error('[mailer] ' + err.message);
          reject(err);
        }
      });
    });
    req.on('error', e => { console.error('[mailer] ' + e.message); reject(e); });
    req.setTimeout(20000, () => { req.destroy(new Error(o.label + '_timeout')); });
    req.write(data); req.end();
  });
}

function sendBrevo(p, to, subject, html, att) {
  const body = { sender: { name: p.from_name, email: p.from_email }, to: [{ email: to }], subject: subject, htmlContent: html };
  if (att && att.length) body.attachment = att.map(a => ({ name: a.filename || a.name || 'attachment', content: b64(a.content) }));
  return httpsJson({ hostname: 'api.brevo.com', path: '/v3/smtp/email', headers: { 'api-key': p.api_key }, label: 'brevo' }, body);
}

function sendResend(p, to, subject, html, att) {
  const from = p.from_name ? (p.from_name + ' <' + p.from_email + '>') : p.from_email;
  const body = { from: from, to: [to], subject: subject, html: html };
  if (att && att.length) body.attachments = att.map(a => ({ filename: a.filename || a.name || 'attachment', content: b64(a.content) }));
  return httpsJson({ hostname: 'api.resend.com', path: '/emails', headers: { 'authorization': 'Bearer ' + p.api_key }, label: 'resend' }, body);
}

function sendZepto(p, to, subject, html, att) {
  const host = p.region === 'in' ? 'api.zeptomail.in' : (p.region === 'eu' ? 'api.zeptomail.eu' : 'api.zeptomail.com');
  const auth = /^Zoho-enczapikey/i.test(p.api_key) ? p.api_key : ('Zoho-enczapikey ' + p.api_key);
  const body = { from: { address: p.from_email, name: p.from_name || '' }, to: [{ email_address: { address: to } }], subject: subject, htmlbody: html };
  if (att && att.length) body.attachments = att.map(a => ({ name: a.filename || a.name || 'attachment', content: b64(a.content) }));
  return httpsJson({ hostname: host, path: '/v1.1/email', headers: { 'authorization': auth }, label: 'zeptomail' }, body);
}

function sendWith(p, to, subject, html, att) {
  to = String(to || '').trim();
  if (!p || !p.api_key || !p.from_email) return Promise.reject(new Error('mail_unconfigured'));
  if (!to) return Promise.reject(new Error('mail_no_recipient'));
  if (p.provider === 'resend') return sendResend(p, to, subject, html, att);
  if (p.provider === 'zeptomail') return sendZepto(p, to, subject, html, att);
  return sendBrevo(p, to, subject, html, att);
}

function markStatus(p, status) {
  try { const db = pool(); if (db && p && p.id) db.query("UPDATE email_providers SET last_status=$1, last_tested_at=now() WHERE id=$2", [String(status).slice(0, 240), p.id]).catch(() => {}); } catch (e) {}
}

async function send(to, subject, html, att) {
  const p = await activeProvider();
  if (!p) throw new Error('mail_unconfigured');
  try {
    const r = await sendWith(p, to, subject, html, att);
    _ready = true; markStatus(p, 'ok');
    return r;
  } catch (e) {
    markStatus(p, e.message);
    throw e;
  }
}

refresh();
try { const t = setInterval(refresh, 60000); if (t && t.unref) t.unref(); } catch (e) {}

module.exports = { configured, send, refresh, activeProvider, sendWith, parseFrom };
EOF
if node -c "$f"; then
  echo "mailer.js syntax OK"
  pm2 restart gsz >/dev/null 2>&1 && echo "gsz restarted" || echo "restart failed"
else
  echo "SYNTAX ERROR -> restoring backup"
  cp "$bak" "$f"
fi
echo "backup: $bak"
echo DONE
