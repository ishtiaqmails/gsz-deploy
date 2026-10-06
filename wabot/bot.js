'use strict';
/* GSZ dedicated WhatsApp VERIFICATION bot (Baileys).
   - Receives customer messages, extracts LID / PN / phone, forwards to the
     website webhook, and replies with whatever the website tells it to.
   - Verification-only: unsupported chatter gets a throttled support redirect.
   - Exposes a tiny secret-gated HTTP send API so the website can push
     order/credential notifications (Phase 2d).
   This is NOT the Galaxy reseller bot. Keep it on its own number + process. */
try { require('dotenv').config(); } catch (e) { /* dotenv optional; env may be set another way */ }
const { default: makeWASocket, useMultiFileAuthState, fetchLatestBaileysVersion, DisconnectReason, makeCacheableSignalKeyStore } = require('@whiskeysockets/baileys');
const { Boom } = require('@hapi/boom');
const P = require('pino');
const http = require('http');
const https = require('https');
const { URL } = require('url');

const WEBSITE_BASE = process.env.WEBSITE_BASE || 'http://127.0.0.1:3900';
const SECRET = process.env.WA_WEBHOOK_SECRET || '';
const BOT_PORT = parseInt(process.env.BOT_PORT || '8095', 10);
const COOLDOWN = parseInt(process.env.UNSUPPORTED_COOLDOWN || '60', 10) * 1000;
const AUTH_DIR = process.env.AUTH_DIR || './auth';
const logger = P({ level: process.env.LOG_LEVEL || 'warn' });

if (!SECRET) { console.error('FATAL: WA_WEBHOOK_SECRET is required (copy wa_settings.wa_bot_webhook_secret from the website).'); process.exit(1); }

// ---- HTTP helper: POST JSON to the website webhook ----
function postWebhook(path, payload) {
  return new Promise((resolve) => {
    try {
      const u = new URL(WEBSITE_BASE + path);
      const data = Buffer.from(JSON.stringify(payload));
      const mod = u.protocol === 'https:' ? https : http;
      const r = mod.request({
        hostname: u.hostname, port: u.port || (u.protocol === 'https:' ? 443 : 80),
        path: u.pathname + u.search, method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': data.length, 'X-WA-Secret': SECRET }
      }, (res) => { let body = ''; res.on('data', d => body += d); res.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { resolve(null); } }); });
      r.on('error', e => { console.error('[webhook] ' + e.message); resolve(null); });
      r.write(data); r.end();
    } catch (e) { resolve(null); }
  });
}

// ---- identity + text extraction ----
function classifyJid(jid) { if (!jid) return {}; if (jid.endsWith('@lid')) return { lid: jid }; if (jid.endsWith('@s.whatsapp.net') || jid.endsWith('@c.us')) return { pnJid: jid }; return {}; }
function buildIdentity(key) {
  const out = {}; Object.assign(out, classifyJid(key.remoteJid));
  const alt = classifyJid(key.remoteJidAlt);          // newer Baileys exposes the other form
  if (alt.lid && !out.lid) out.lid = alt.lid;
  if (alt.pnJid && !out.pnJid) out.pnJid = alt.pnJid;
  if (!out.lid) { const p = classifyJid(key.participant); if (p.lid) out.lid = p.lid; }
  if (!out.pnJid) { const pa = classifyJid(key.participantAlt); if (pa.pnJid) out.pnJid = pa.pnJid; }
  // Newer Baileys may expose the real phone for a LID sender via senderPn/participantPn.
  if (!out.pnJid && key.senderPn && classifyJid(key.senderPn).pnJid) out.pnJid = key.senderPn;
  if (!out.pnJid && key.participantPn && classifyJid(key.participantPn).pnJid) out.pnJid = key.participantPn;
  if (out.pnJid && String(out.pnJid).indexOf('@') >= 0 && !String(out.pnJid).toLowerCase().endsWith('@lid')) out.phone = String(out.pnJid).split('@')[0];
  out.jid = key.remoteJid;
  return out;
}
function extractText(m) {
  const msg = m.message || {};
  return msg.conversation
    || (msg.extendedTextMessage && msg.extendedTextMessage.text)
    || (msg.imageMessage && msg.imageMessage.caption)
    || (msg.buttonsResponseMessage && msg.buttonsResponseMessage.selectedDisplayText)
    || (msg.listResponseMessage && msg.listResponseMessage.title)
    || (msg.templateButtonReplyMessage && msg.templateButtonReplyMessage.selectedDisplayText)
    || '';
}

const lastRedirect = new Map();
let sock = null;

async function start() {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
  const { version } = await fetchLatestBaileysVersion();
  sock = makeWASocket({
    version,
    auth: { creds: state.creds, keys: makeCacheableSignalKeyStore(state.keys, logger) },
    logger, markOnlineOnConnect: false, syncFullHistory: false
  });

  sock.ev.on('creds.update', saveCreds);

  sock.ev.on('connection.update', (u) => {
    const { connection, lastDisconnect, qr } = u;
    if (qr) { try { require('qrcode-terminal').generate(qr, { small: true }); } catch (e) { console.log('Scan this QR (raw):', qr); } }
    if (connection === 'open') console.log('[wabot] connected as ' + (sock.user && sock.user.id));
    if (connection === 'close') {
      const code = (lastDisconnect && lastDisconnect.error && new Boom(lastDisconnect.error).output.statusCode) || 0;
      const loggedOut = code === DisconnectReason.loggedOut;
      console.log('[wabot] closed (' + code + ')' + (loggedOut ? ' — logged out; delete the auth folder and re-scan.' : ' — reconnecting'));
      if (!loggedOut) setTimeout(() => start().catch(e => console.error('[wabot] restart ' + e.message)), 3000);
    }
  });

  sock.ev.on('messages.upsert', async (ev) => {
    if (ev.type !== 'notify') return;
    for (const m of ev.messages) {
      try {
        if (!m.message || (m.key && m.key.fromMe)) continue;
        const jid = (m.key && m.key.remoteJid) || '';
        if (!jid || jid.endsWith('@g.us') || jid === 'status@broadcast' || jid.endsWith('@newsletter')) continue; // DMs only
        const ts = Number(m.messageTimestamp) || 0;                 // skip stale/history messages (keeps live replies fast)
        if (ts && (Date.now() / 1000 - ts) > 90) continue;
        const text = extractText(m).trim();
        const ident = buildIdentity(m.key);
        const resp = await postWebhook('/internal/whatsapp/incoming', { lid: ident.lid || null, pnJid: ident.pnJid || null, phone: ident.phone || null, jid: ident.jid, text });
        if (!resp || !resp.reply) continue;
        if (resp.action === 'REDIRECT') {
          const last = lastRedirect.get(jid) || 0;
          if (Date.now() - last < COOLDOWN) continue;        // throttle unsupported spam
          lastRedirect.set(jid, Date.now());
        }
        await sock.sendMessage(jid, { text: resp.reply });
      } catch (e) { console.error('[wabot msg] ' + e.message); }
    }
  });
}

// ---- send API (website -> bot), secret-gated ----
http.createServer((req, res) => {
  if ((req.headers['x-wa-secret'] || '') !== SECRET) { res.writeHead(401, { 'Content-Type': 'application/json' }); return res.end('{"ok":false,"error":"unauthorized"}'); }
  if (req.method === 'GET' && req.url === '/health') {
    const connected = !!(sock && sock.user);
    res.writeHead(200, { 'Content-Type': 'application/json' }); return res.end(JSON.stringify({ ok: true, connected }));
  }
  if (req.method === 'POST' && req.url === '/send') {
    let b = ''; req.on('data', d => b += d); req.on('end', async () => {
      try {
        const { to, text } = JSON.parse(b || '{}');
        if (!to || !text) { res.writeHead(400, { 'Content-Type': 'application/json' }); return res.end('{"ok":false,"error":"to+text required"}'); }
        if (!sock || !sock.user) { res.writeHead(503, { 'Content-Type': 'application/json' }); return res.end('{"ok":false,"error":"not connected"}'); }
        const jid = String(to).indexOf('@') >= 0 ? String(to) : (String(to).replace(/[^0-9]/g, '') + '@s.whatsapp.net');
        const r = await sock.sendMessage(jid, { text: String(text) });
        res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ ok: true, id: r && r.key && r.key.id }));
      } catch (e) { res.writeHead(500, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ ok: false, error: e.message })); }
    });
    return;
  }
  res.writeHead(404, { 'Content-Type': 'application/json' }); res.end('{"ok":false}');
}).listen(BOT_PORT, () => console.log('[wabot] send API listening on :' + BOT_PORT));

start().catch(e => { console.error('[wabot] fatal ' + e.message); process.exit(1); });
