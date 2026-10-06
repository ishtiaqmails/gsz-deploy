#!/usr/bin/env bash
# step83 — fix wa_bot_send_url to include the /send path (was 404) and retry
# the queued test message immediately. DB-only; no app/file changes.
set -euo pipefail
cd /opt/gsz
node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{
  const cur = (await p.query("SELECT value FROM wa_settings WHERE key='wa_bot_send_url'")).rows[0];
  let url = (cur && cur.value) || 'http://127.0.0.1:8095';
  if (!/\/send$/.test(url)) url = url.replace(/\/+$/,'') + '/send';
  await p.query("INSERT INTO wa_settings(key,value) VALUES('wa_bot_send_url',$1) ON CONFLICT(key) DO UPDATE SET value=$1, updated_at=now()", [url]);
  console.log('   wa_bot_send_url = ' + url);
  const r = await p.query("UPDATE wa_notifications SET status='QUEUED', next_attempt_at=now(), last_error=NULL WHERE status IN ('QUEUED','FAILED','SENDING')");
  console.log('   re-queued ' + r.rowCount + ' pending message(s) for immediate retry');
  await p.end();
})().catch(e=>{ console.error('FAIL: '+e.message); process.exit(1); });
NODE

echo "==> waiting for the worker to deliver..."
sleep 12
node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{
  const q = (await p.query("SELECT status, count(*)::int n FROM wa_notifications GROUP BY status ORDER BY status")).rows;
  console.log('   outbox: ' + (q.map(r=>r.status+'='+r.n).join(' ') || '(empty)'));
  const last = (await p.query("SELECT template_key, status, destination_phone, last_error FROM wa_notifications ORDER BY id DESC LIMIT 3")).rows;
  last.forEach(r=>console.log('    - '+r.template_key+' -> '+r.status+(r.destination_phone?(' to '+r.destination_phone):'')+(r.last_error?(' ('+r.last_error+')'):'')));
  await p.end();
})().catch(e=>{ console.error(e.message); p.end(); });
NODE
echo "==> step83 done — a SENT row means it reached your WhatsApp."
