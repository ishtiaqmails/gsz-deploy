#!/usr/bin/env bash
# step81 — WhatsApp module Phase 2d: notification OUTBOX WORKER.
# Adds lib/wanotify.js (polls wa_notifications, sends via the bot send API with
# retry/backoff + idempotency), a next_attempt_at column, the wa_notifications_enabled
# flag, and starts the worker from server.js. Idempotent; rolls back server.js.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step81-$TS
mkdir -p "$BAK/lib"
cp "$APP/server.js" "$BAK/server.js"
[ -f "$APP/lib/wanotify.js" ] && cp "$APP/lib/wanotify.js" "$BAK/lib/wanotify.js" || true
restore(){ echo "!! rollback"; cp "$BAK/server.js" "$APP/server.js"; [ -f "$BAK/lib/wanotify.js" ] && cp "$BAK/lib/wanotify.js" "$APP/lib/wanotify.js" || rm -f "$APP/lib/wanotify.js"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR
cd "$APP"

echo "==> write lib/wanotify.js"
base64 -d > "$APP/lib/wanotify.js" <<'B64'
J3VzZSBzdHJpY3QnOwovKiBXaGF0c0FwcCBub3RpZmljYXRpb24gb3V0Ym94IHdvcmtlciAoUGhhc2UgMmQpLgogICBQb2xscyB3YV9ub3RpZmljYXRpb25zIGZvciBRVUVVRUQgcm93cywgcmVuZGVycyB0aGUgdGVtcGxhdGUsIHJlc29sdmVzIHRoZQogICByZWNpcGllbnQgKGNhcHR1cmVkIFBOIC0+IHByb2ZpbGUgbnVtYmVyIC0+IExJRCBqaWQpLCBhbmQgcG9zdHMgdG8gdGhlIGJvdCdzCiAgIHNlbmQgQVBJLiBSZXRyaWVzIHRyYW5zaWVudCBmYWlsdXJlcyB3aXRoIGJhY2tvZmYsIGNhcHMgYXR0ZW1wdHMsIGFuZCBpcwogICBpZGVtcG90ZW50ICh1bmlxdWUgaWRlbXBvdGVuY3lfa2V5IG9uIGVucXVldWUpLiBOZXZlciBjcmFzaGVzIHRoZSBhcHAuICovCmNvbnN0IGh0dHAgPSByZXF1aXJlKCdodHRwJyk7CmNvbnN0IGh0dHBzID0gcmVxdWlyZSgnaHR0cHMnKTsKY29uc3QgeyBVUkwgfSA9IHJlcXVpcmUoJ3VybCcpOwoKbW9kdWxlLmV4cG9ydHMgPSBmdW5jdGlvbiAocG9vbCkgewogIGFzeW5jIGZ1bmN0aW9uIHNldHRpbmdzKCkgeyBjb25zdCByID0gYXdhaXQgcG9vbC5xdWVyeSgnU0VMRUNUIGtleSx2YWx1ZSBGUk9NIHdhX3NldHRpbmdzJyk7IGNvbnN0IG8gPSB7fTsgci5yb3dzLmZvckVhY2goeCA9PiBvW3gua2V5XSA9IHgudmFsdWUpOyByZXR1cm4gbzsgfQogIGFzeW5jIGZ1bmN0aW9uIHRwbChrZXkpIHsgY29uc3QgciA9IGF3YWl0IHBvb2wucXVlcnkoJ1NFTEVDVCBib2R5IEZST00gd2FfdGVtcGxhdGVzIFdIRVJFIGtleT0kMScsIFtrZXldKTsgcmV0dXJuIHIucm93c1swXSA/IHIucm93c1swXS5ib2R5IDogJyc7IH0KICBmdW5jdGlvbiByZW5kZXIoYm9keSwgdmFycykgeyByZXR1cm4gU3RyaW5nKGJvZHkgfHwgJycpLnJlcGxhY2UoL1x7XHsoXHcrKVx9XH0vZywgKF8sIGspID0+ICh2YXJzICYmIHZhcnNba10gIT0gbnVsbCkgPyBTdHJpbmcodmFyc1trXSkgOiAnJyk7IH0KCiAgZnVuY3Rpb24gcG9zdFNlbmQoc2VuZFVybCwgc2VjcmV0LCBwYXlsb2FkKSB7CiAgICByZXR1cm4gbmV3IFByb21pc2UocmVzb2x2ZSA9PiB7CiAgICAgIHRyeSB7CiAgICAgICAgY29uc3QgdSA9IG5ldyBVUkwoc2VuZFVybCk7CiAgICAgICAgY29uc3QgZGF0YSA9IEJ1ZmZlci5mcm9tKEpTT04uc3RyaW5naWZ5KHBheWxvYWQpKTsKICAgICAgICBjb25zdCBtb2QgPSB1LnByb3RvY29sID09PSAnaHR0cHM6JyA/IGh0dHBzIDogaHR0cDsKICAgICAgICBjb25zdCByID0gbW9kLnJlcXVlc3QoewogICAgICAgICAgaG9zdG5hbWU6IHUuaG9zdG5hbWUsIHBvcnQ6IHUucG9ydCB8fCAodS5wcm90b2NvbCA9PT0gJ2h0dHBzOicgPyA0NDMgOiA4MCksCiAgICAgICAgICBwYXRoOiB1LnBhdGhuYW1lICsgdS5zZWFyY2gsIG1ldGhvZDogJ1BPU1QnLAogICAgICAgICAgaGVhZGVyczogeyAnQ29udGVudC1UeXBlJzogJ2FwcGxpY2F0aW9uL2pzb24nLCAnQ29udGVudC1MZW5ndGgnOiBkYXRhLmxlbmd0aCwgJ1gtV0EtU2VjcmV0Jzogc2VjcmV0IH0KICAgICAgICB9LCByZXMgPT4geyBsZXQgYiA9ICcnOyByZXMub24oJ2RhdGEnLCBkID0+IGIgKz0gZCk7IHJlcy5vbignZW5kJywgKCkgPT4geyBsZXQgaiA9IG51bGw7IHRyeSB7IGogPSBKU09OLnBhcnNlKGIpOyB9IGNhdGNoIChlKSB7fSByZXNvbHZlKHsgc3RhdHVzOiByZXMuc3RhdHVzQ29kZSwgYm9keTogaiB9KTsgfSk7IH0pOwogICAgICAgIHIub24oJ2Vycm9yJywgZSA9PiByZXNvbHZlKHsgc3RhdHVzOiAwLCBlcnJvcjogZS5tZXNzYWdlIH0pKTsKICAgICAgICByLnNldFRpbWVvdXQoMTIwMDAsICgpID0+IHsgdHJ5IHsgci5kZXN0cm95KCk7IH0gY2F0Y2ggKGUpIHt9IHJlc29sdmUoeyBzdGF0dXM6IDAsIGVycm9yOiAndGltZW91dCcgfSk7IH0pOwogICAgICAgIHIud3JpdGUoZGF0YSk7IHIuZW5kKCk7CiAgICAgIH0gY2F0Y2ggKGUpIHsgcmVzb2x2ZSh7IHN0YXR1czogMCwgZXJyb3I6IGUubWVzc2FnZSB9KTsgfQogICAgfSk7CiAgfQoKICBhc3luYyBmdW5jdGlvbiByZXNvbHZlUmVjaXBpZW50KG4pIHsKICAgIGlmIChuLmRlc3RpbmF0aW9uX3Bob25lKSByZXR1cm4gbi5kZXN0aW5hdGlvbl9waG9uZTsKICAgIGlmIChuLmRlc3RpbmF0aW9uX2lkZW50aXR5X2lkKSB7CiAgICAgIGNvbnN0IGkgPSAoYXdhaXQgcG9vbC5xdWVyeSgnU0VMRUNUIGN1cnJlbnRfcGhvbmVfZTE2NCwgY2Fub25pY2FsX2xpZCBGUk9NIHdoYXRzYXBwX2lkZW50aXRpZXMgV0hFUkUgaWQ9JDEnLCBbbi5kZXN0aW5hdGlvbl9pZGVudGl0eV9pZF0pKS5yb3dzWzBdOwogICAgICBpZiAoaSAmJiBpLmN1cnJlbnRfcGhvbmVfZTE2NCkgcmV0dXJuIGkuY3VycmVudF9waG9uZV9lMTY0OwogICAgfQogICAgaWYgKG4uY3VzdG9tZXJfaWQpIHsKICAgICAgY29uc3QgYyA9IChhd2FpdCBwb29sLnF1ZXJ5KCdTRUxFQ1Qgd2FfbnVtYmVyIEZST00gY3VzdG9tZXJzIFdIRVJFIGlkPSQxJywgW24uY3VzdG9tZXJfaWRdKSkucm93c1swXTsKICAgICAgaWYgKGMgJiYgYy53YV9udW1iZXIpIHJldHVybiBjLndhX251bWJlcjsKICAgIH0KICAgIGlmIChuLmRlc3RpbmF0aW9uX2lkZW50aXR5X2lkKSB7CiAgICAgIGNvbnN0IGkgPSAoYXdhaXQgcG9vbC5xdWVyeSgnU0VMRUNUIGNhbm9uaWNhbF9saWQgRlJPTSB3aGF0c2FwcF9pZGVudGl0aWVzIFdIRVJFIGlkPSQxJywgW24uZGVzdGluYXRpb25faWRlbnRpdHlfaWRdKSkucm93c1swXTsKICAgICAgaWYgKGkgJiYgaS5jYW5vbmljYWxfbGlkKSByZXR1cm4gaS5jYW5vbmljYWxfbGlkICsgJ0BsaWQnOyAgIC8vIGxhc3QgcmVzb3J0OiBtZXNzYWdlIHRoZSBMSUQgZGlyZWN0bHkKICAgIH0KICAgIHJldHVybiBudWxsOwogIH0KCiAgYXN5bmMgZnVuY3Rpb24gdGljaygpIHsKICAgIGxldCBzOwogICAgdHJ5IHsgcyA9IGF3YWl0IHNldHRpbmdzKCk7IH0gY2F0Y2ggKGUpIHsgcmV0dXJuOyB9CiAgICBpZiAocy53YV9ub3RpZmljYXRpb25zX2VuYWJsZWQgPT09ICcwJykgcmV0dXJuOwogICAgY29uc3Qgc2VuZFVybCA9IHMud2FfYm90X3NlbmRfdXJsLCBzZWNyZXQgPSBzLndhX2JvdF93ZWJob29rX3NlY3JldDsKICAgIGlmICghc2VuZFVybCB8fCAhc2VjcmV0KSByZXR1cm47CiAgICBsZXQgY2xhaW1lZCA9IFtdOwogICAgdHJ5IHsKICAgICAgY2xhaW1lZCA9IChhd2FpdCBwb29sLnF1ZXJ5KAogICAgICAgICJVUERBVEUgd2Ffbm90aWZpY2F0aW9ucyBTRVQgc3RhdHVzPSdTRU5ESU5HJyBXSEVSRSBpZCBJTiAoU0VMRUNUIGlkIEZST00gd2Ffbm90aWZpY2F0aW9ucyBXSEVSRSBzdGF0dXM9J1FVRVVFRCcgQU5EIG5leHRfYXR0ZW1wdF9hdCA8PSBub3coKSBPUkRFUiBCWSBxdWV1ZWRfYXQgTElNSVQgNSBGT1IgVVBEQVRFIFNLSVAgTE9DS0VEKSBSRVRVUk5JTkcgKiIpKS5yb3dzOwogICAgfSBjYXRjaCAoZSkgeyByZXR1cm47IH0KICAgIGZvciAoY29uc3QgbiBvZiBjbGFpbWVkKSB7CiAgICAgIHRyeSB7CiAgICAgICAgY29uc3QgdG8gPSBhd2FpdCByZXNvbHZlUmVjaXBpZW50KG4pOwogICAgICAgIGlmICghdG8pIHsgYXdhaXQgcG9vbC5xdWVyeSgiVVBEQVRFIHdhX25vdGlmaWNhdGlvbnMgU0VUIHN0YXR1cz0nRkFJTEVEJywgZmFpbGVkX2F0PW5vdygpLCBsYXN0X2Vycm9yPSdubyByZWNpcGllbnQnIFdIRVJFIGlkPSQxIiwgW24uaWRdKTsgY29udGludWU7IH0KICAgICAgICBjb25zdCB2YXJzID0gT2JqZWN0LmFzc2lnbih7fSwgbi52YXJzIHx8IHt9KTsKICAgICAgICBpZiAodmFycy5zYWxlc19udW1iZXIgPT0gbnVsbCkgdmFycy5zYWxlc19udW1iZXIgPSBzLndhX3NhbGVzX251bWJlciB8fCAnJzsKICAgICAgICBpZiAodmFycy5zdXBwb3J0X251bWJlciA9PSBudWxsKSB2YXJzLnN1cHBvcnRfbnVtYmVyID0gcy53YV9zdXBwb3J0X251bWJlciB8fCAnJzsKICAgICAgICBjb25zdCB0ZXh0ID0gcmVuZGVyKGF3YWl0IHRwbChuLnRlbXBsYXRlX2tleSksIHZhcnMpIHx8ICgnKCcgKyBuLnRlbXBsYXRlX2tleSArICcpJyk7CiAgICAgICAgY29uc3QgciA9IGF3YWl0IHBvc3RTZW5kKHNlbmRVcmwsIHNlY3JldCwgeyB0bywgdGV4dCB9KTsKICAgICAgICBpZiAoci5zdGF0dXMgPT09IDIwMCAmJiByLmJvZHkgJiYgci5ib2R5Lm9rKSB7CiAgICAgICAgICBhd2FpdCBwb29sLnF1ZXJ5KCJVUERBVEUgd2Ffbm90aWZpY2F0aW9ucyBTRVQgc3RhdHVzPSdTRU5UJywgc2VudF9hdD1ub3coKSwgcHJvdmlkZXJfbWVzc2FnZV9pZD0kMiBXSEVSRSBpZD0kMSIsIFtuLmlkLCAoci5ib2R5LmlkIHx8IG51bGwpXSk7CiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgIGNvbnN0IGF0dCA9IChuLmF0dGVtcHRzIHx8IDApICsgMTsKICAgICAgICAgIGNvbnN0IGVyciA9IChyLmJvZHkgJiYgci5ib2R5LmVycm9yKSB8fCByLmVycm9yIHx8ICgnaHR0cCAnICsgci5zdGF0dXMpOwogICAgICAgICAgaWYgKGF0dCA+PSA1KSBhd2FpdCBwb29sLnF1ZXJ5KCJVUERBVEUgd2Ffbm90aWZpY2F0aW9ucyBTRVQgc3RhdHVzPSdGQUlMRUQnLCBmYWlsZWRfYXQ9bm93KCksIGF0dGVtcHRzPSQyLCBsYXN0X2Vycm9yPSQzIFdIRVJFIGlkPSQxIiwgW24uaWQsIGF0dCwgZXJyXSk7CiAgICAgICAgICBlbHNlIGF3YWl0IHBvb2wucXVlcnkoIlVQREFURSB3YV9ub3RpZmljYXRpb25zIFNFVCBzdGF0dXM9J1FVRVVFRCcsIGF0dGVtcHRzPSQyLCBsYXN0X2Vycm9yPSQzLCBuZXh0X2F0dGVtcHRfYXQ9bm93KCkgKyAoJDR8fCcgc2Vjb25kcycpOjppbnRlcnZhbCBXSEVSRSBpZD0kMSIsIFtuLmlkLCBhdHQsIGVyciwgU3RyaW5nKGF0dCAqIDMwKV0pOwogICAgICAgIH0KICAgICAgfSBjYXRjaCAoZSkgewogICAgICAgIHRyeSB7CiAgICAgICAgICBjb25zdCBhdHQgPSAobi5hdHRlbXB0cyB8fCAwKSArIDE7CiAgICAgICAgICBhd2FpdCBwb29sLnF1ZXJ5KCJVUERBVEUgd2Ffbm90aWZpY2F0aW9ucyBTRVQgc3RhdHVzPUNBU0UgV0hFTiAkMj49NSBUSEVOICdGQUlMRUQnIEVMU0UgJ1FVRVVFRCcgRU5ELCBhdHRlbXB0cz0kMiwgbGFzdF9lcnJvcj0kMywgbmV4dF9hdHRlbXB0X2F0PW5vdygpICsgKCQ0fHwnIHNlY29uZHMnKTo6aW50ZXJ2YWwsIGZhaWxlZF9hdD1DQVNFIFdIRU4gJDI+PTUgVEhFTiBub3coKSBFTFNFIGZhaWxlZF9hdCBFTkQgV0hFUkUgaWQ9JDEiLCBbbi5pZCwgYXR0LCBTdHJpbmcoZS5tZXNzYWdlKSwgU3RyaW5nKGF0dCAqIDMwKV0pOwogICAgICAgIH0gY2F0Y2ggKF8pIHt9CiAgICAgIH0KICAgIH0KICB9CgogIGZ1bmN0aW9uIHN0YXJ0V29ya2VyKCkgewogICAgY29uc3QgaXYgPSBwYXJzZUludChwcm9jZXNzLmVudi5XQV9XT1JLRVJfSU5URVJWQUxfTVMgfHwgJzEwMDAwJywgMTApOwogICAgc2V0SW50ZXJ2YWwoKCkgPT4geyB0aWNrKCkuY2F0Y2goKCkgPT4ge30pOyB9LCBpdik7CiAgICBjb25zb2xlLmxvZygnW3dhbm90aWZ5XSBvdXRib3ggd29ya2VyIHN0YXJ0ZWQgKGV2ZXJ5ICcgKyBpdiArICdtcyknKTsKICB9CgogIC8vIEhlbHBlciBmb3Igb3RoZXIgbW9kdWxlcyB0byBxdWV1ZSBhIG5vdGlmaWNhdGlvbi4KICBhc3luYyBmdW5jdGlvbiBlbnF1ZXVlKG8pIHsKICAgIHJldHVybiBwb29sLnF1ZXJ5KAogICAgICAiSU5TRVJUIElOVE8gd2Ffbm90aWZpY2F0aW9ucyhjdXN0b21lcl9pZCxvcmRlcl9pZCxkZXN0aW5hdGlvbl9pZGVudGl0eV9pZCxkZXN0aW5hdGlvbl9waG9uZSx0ZW1wbGF0ZV9rZXksdmFycyxpZGVtcG90ZW5jeV9rZXkpIFZBTFVFUygkMSwkMiwkMywkNCwkNSwkNiwkNykgT04gQ09ORkxJQ1QoaWRlbXBvdGVuY3lfa2V5KSBETyBOT1RISU5HIiwKICAgICAgW28uY3VzdG9tZXJfaWQgfHwgbnVsbCwgby5vcmRlcl9pZCB8fCBudWxsLCBvLmRlc3RpbmF0aW9uX2lkZW50aXR5X2lkIHx8IG51bGwsIG8uZGVzdGluYXRpb25fcGhvbmUgfHwgbnVsbCwgby50ZW1wbGF0ZV9rZXksIEpTT04uc3RyaW5naWZ5KG8udmFycyB8fCB7fSksIG8uaWRlbXBvdGVuY3lfa2V5IHx8IG51bGxdKTsKICB9CgogIHJldHVybiB7IHN0YXJ0V29ya2VyLCBlbnF1ZXVlLCB0aWNrIH07Cn07Cg==
B64
node --check "$APP/lib/wanotify.js" && echo "   wanotify syntax OK"

echo "==> migrate: next_attempt_at + wa_notifications_enabled"
node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{
  await p.query("ALTER TABLE wa_notifications ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz NOT NULL DEFAULT now()");
  await p.query("CREATE INDEX IF NOT EXISTS wa_notif_due_idx ON wa_notifications(status, next_attempt_at)");
  await p.query("INSERT INTO wa_settings(key,value) VALUES('wa_notifications_enabled','1') ON CONFLICT(key) DO NOTHING");
  const q = (await p.query("SELECT status, count(*)::int n FROM wa_notifications GROUP BY status")).rows;
  console.log('   outbox before worker: ' + (q.map(r=>r.status+'='+r.n).join(' ') || '(empty)'));
  await p.end();
})().catch(e=>{ console.error('MIGRATION FAIL: '+e.message); process.exit(1); });
NODE

echo "==> patch server.js (start worker)"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/server.js'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf('wanotify')>=0){ console.log('   server.js already patched'); }
else {
  const anc="const whatsappRouter = require('./routes/whatsapp')(pool);\napp.use('/', whatsappRouter);";
  if(s.indexOf(anc)<0){ console.error('!! whatsapp mount anchor not found'); process.exit(2); }
  s=s.replace(anc, anc+"\ntry { require('./lib/wanotify')(pool).startWorker(); } catch (e) { console.log('[wanotify] ' + e.message); }");
  fs.writeFileSync(f,s); console.log('   server.js patched');
}
NODE

echo "==> node --check + restart"; node --check "$APP/server.js"; pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }

echo "==> wait for worker to drain the queue (any already-queued messages send now)"
sleep 12
node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{
  const q = (await p.query("SELECT status, count(*)::int n FROM wa_notifications GROUP BY status ORDER BY status")).rows;
  console.log('   outbox now: ' + (q.map(r=>r.status+'='+r.n).join(' ') || '(empty)'));
  const last = (await p.query("SELECT template_key, status, last_error, destination_phone FROM wa_notifications ORDER BY id DESC LIMIT 3")).rows;
  last.forEach(r=>console.log('    - '+r.template_key+' -> '+r.status+(r.last_error?(' ('+r.last_error+')'):'')));
  await p.end();
})().catch(e=>{ console.error(e.message); p.end(); });
NODE
trap - ERR
echo "==> step81 OK — notification outbox worker live. Backup: $BAK"
echo "   A SENT row means the queued verification message was delivered — check your WhatsApp."
