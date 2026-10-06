#!/usr/bin/env bash
# step91 — Phase 4a: Trials admin. Adds trial_servers config, extends
# trial_claims, the /admin/trials page, botapi.generateTrial, the server mount,
# and the nav link. Customer claim flow comes in 4b. Idempotent; rolls back.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step91-$TS
mkdir -p "$BAK/routes" "$BAK/lib" "$BAK/views/admin"
cp "$APP/server.js" "$BAK/server.js"
cp "$APP/lib/botapi.js" "$BAK/lib/botapi.js"
cp "$APP/views/admin/_shell_top.ejs" "$BAK/views/admin/_shell_top.ejs"
restore(){ echo "!! rollback"; cp "$BAK/server.js" "$APP/server.js"; cp "$BAK/lib/botapi.js" "$APP/lib/botapi.js"; cp "$BAK/views/admin/_shell_top.ejs" "$APP/views/admin/_shell_top.ejs"; rm -f "$APP/routes/adminTrials.js" "$APP/views/admin/trials.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR
cd "$APP"

echo "==> migrate: trial_servers + trial_claims columns"
node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{
  await p.query(`CREATE TABLE IF NOT EXISTS trial_servers(
    sku text PRIMARY KEY, name text, enabled boolean NOT NULL DEFAULT false,
    duration_label text, duration_hours integer NOT NULL DEFAULT 24,
    max_per_customer integer NOT NULL DEFAULT 1, updated_at timestamptz NOT NULL DEFAULT now())`);
  await p.query("ALTER TABLE trial_claims ADD COLUMN IF NOT EXISTS expires_at timestamptz");
  await p.query("ALTER TABLE trial_claims ADD COLUMN IF NOT EXISTS credentials text");
  await p.query("ALTER TABLE trial_claims ADD COLUMN IF NOT EXISTS bot_ref text");
  await p.query("ALTER TABLE trial_claims ADD COLUMN IF NOT EXISTS server_name text");
  await p.query("ALTER TABLE trial_claims ADD COLUMN IF NOT EXISTS duration_hours integer");
  // the old unique assumed max=1 per identity+server; quota is now configurable, enforced in-app
  await p.query("DROP INDEX IF EXISTS trial_claims_identity_type_uidx");
  await p.query("CREATE INDEX IF NOT EXISTS trial_claims_identity_type_idx ON trial_claims(whatsapp_identity_id, trial_type)");
  const n = (await p.query("SELECT count(*)::int n FROM trial_servers")).rows[0].n;
  console.log('   trial_servers ready ('+n+' configured) + trial_claims extended');
  await p.end();
})().catch(e=>{ console.error('MIGRATION FAIL: '+e.message); process.exit(1); });
NODE

echo "==> write admin route + view"
mkdir -p "$APP/routes" "$APP/views/admin"
base64 -d > "$APP/routes/adminTrials.js" <<'B64'
Y29uc3QgZXhwcmVzcyA9IHJlcXVpcmUoJ2V4cHJlc3MnKTsKCm1vZHVsZS5leHBvcnRzID0gZnVuY3Rpb24gKHBvb2wpIHsKICBjb25zdCByb3V0ZXIgPSBleHByZXNzLlJvdXRlcigpOwogIGNvbnN0IGJvZHkgPSBleHByZXNzLnVybGVuY29kZWQoeyBleHRlbmRlZDogdHJ1ZSB9KTsKICBmdW5jdGlvbiBhdXRoKHJlcSwgcmVzLCBuZXh0KSB7IGlmIChyZXEuc2Vzc2lvbiAmJiByZXEuc2Vzc2lvbi5hZG1pbikgcmV0dXJuIG5leHQoKTsgcmV0dXJuIHJlcy5yZWRpcmVjdCgnL2FkbWluL2xvZ2luJyk7IH0KCiAgLy8gTGlzdCBJUFRWIHNlcnZlcnMgKGZyb20gYm90IG1hcHBpbmcpIHdpdGggdGhlaXIgdHJpYWwgY29uZmlnLgogIHJvdXRlci5nZXQoJy90cmlhbHMnLCBhdXRoLCBhc3luYyAocmVxLCByZXMpID0+IHsKICAgIGxldCByb3dzID0gW107CiAgICB0cnkgewogICAgICByb3dzID0gKGF3YWl0IHBvb2wucXVlcnkoCiAgICAgICAgYFNFTEVDVCBicC5za3UsIGJwLm5hbWUsIHRzLmVuYWJsZWQsIHRzLmR1cmF0aW9uX2xhYmVsLCB0cy5kdXJhdGlvbl9ob3VycywgdHMubWF4X3Blcl9jdXN0b21lcgogICAgICAgICBGUk9NIGJvdF9wcm9kdWN0cyBicCBMRUZUIEpPSU4gdHJpYWxfc2VydmVycyB0cyBPTiB0cy5za3UgPSBicC5za3UKICAgICAgICAgV0hFUkUgbG93ZXIoY29hbGVzY2UoYnAuZGVsaXZlcnlfdHlwZSwnJykpID0gJ2lwdHYnCiAgICAgICAgIE9SREVSIEJZIGJwLm5hbWVgKSkucm93czsKICAgIH0gY2F0Y2ggKGUpIHsgcm93cyA9IFtdOyB9CiAgICByZXMucmVuZGVyKCdhZG1pbi90cmlhbHMnLCB7IHJvd3MsIGZsYXNoOiByZXEucXVlcnkub2sgfHwgbnVsbCB9KTsKICB9KTsKCiAgLy8gU2F2ZSBvbmUgc2VydmVyJ3MgdHJpYWwgY29uZmlnLgogIHJvdXRlci5wb3N0KCcvdHJpYWxzL3NhdmUnLCBhdXRoLCBib2R5LCBhc3luYyAocmVxLCByZXMpID0+IHsKICAgIGNvbnN0IGIgPSByZXEuYm9keTsgY29uc3Qgc2t1ID0gKGIuc2t1IHx8ICcnKS50cmltKCk7CiAgICBpZiAoIXNrdSkgcmV0dXJuIHJlcy5yZWRpcmVjdCgnL2FkbWluL3RyaWFscz9vaz1NaXNzaW5nK3NlcnZlcicpOwogICAgY29uc3QgZW5hYmxlZCA9IGIuZW5hYmxlZCA/IHRydWUgOiBmYWxzZTsKICAgIGNvbnN0IGR1cmF0aW9uX2xhYmVsID0gKGIuZHVyYXRpb25fbGFiZWwgfHwgJycpLnRyaW0oKTsKICAgIGNvbnN0IGR1cmF0aW9uX2hvdXJzID0gcGFyc2VJbnQoYi5kdXJhdGlvbl9ob3VycywgMTApIHx8IDI0OwogICAgbGV0IG1heCA9IHBhcnNlSW50KGIubWF4X3Blcl9jdXN0b21lciwgMTApOyBpZiAoIShtYXggPj0gMSkpIG1heCA9IDE7CiAgICBjb25zdCBicCA9IChhd2FpdCBwb29sLnF1ZXJ5KCdTRUxFQ1QgbmFtZSBGUk9NIGJvdF9wcm9kdWN0cyBXSEVSRSBza3U9JDEnLCBbc2t1XSkpLnJvd3NbMF0gfHwge307CiAgICBhd2FpdCBwb29sLnF1ZXJ5KAogICAgICBgSU5TRVJUIElOVE8gdHJpYWxfc2VydmVycyhza3UsbmFtZSxlbmFibGVkLGR1cmF0aW9uX2xhYmVsLGR1cmF0aW9uX2hvdXJzLG1heF9wZXJfY3VzdG9tZXIsdXBkYXRlZF9hdCkKICAgICAgIFZBTFVFUygkMSwkMiwkMywkNCwkNSwkNixub3coKSkKICAgICAgIE9OIENPTkZMSUNUKHNrdSkgRE8gVVBEQVRFIFNFVCBuYW1lPUVYQ0xVREVELm5hbWUsIGVuYWJsZWQ9RVhDTFVERUQuZW5hYmxlZCwKICAgICAgICAgZHVyYXRpb25fbGFiZWw9RVhDTFVERUQuZHVyYXRpb25fbGFiZWwsIGR1cmF0aW9uX2hvdXJzPUVYQ0xVREVELmR1cmF0aW9uX2hvdXJzLAogICAgICAgICBtYXhfcGVyX2N1c3RvbWVyPUVYQ0xVREVELm1heF9wZXJfY3VzdG9tZXIsIHVwZGF0ZWRfYXQ9bm93KClgLAogICAgICBbc2t1LCBicC5uYW1lIHx8IHNrdSwgZW5hYmxlZCwgZHVyYXRpb25fbGFiZWwsIGR1cmF0aW9uX2hvdXJzLCBtYXhdKTsKICAgIHJlcy5yZWRpcmVjdCgnL2FkbWluL3RyaWFscz9vaz0nICsgZW5jb2RlVVJJQ29tcG9uZW50KCdTYXZlZDogJyArIChicC5uYW1lIHx8IHNrdSkpKTsKICB9KTsKCiAgcmV0dXJuIHJvdXRlcjsKfTsK
B64
base64 -d > "$APP/views/admin/trials.ejs" <<'B64'
PCUtIGluY2x1ZGUoJ19zaGVsbF90b3AnLCB7IGFjdGl2ZTondHJpYWxzJywgdGl0bGU6J1RyaWFscycgfSkgJT4KPHAgY2xhc3M9InN1YiI+VHVybiBmcmVlIHRyaWFscyBvbiBwZXIgSVBUViBzZXJ2ZXIsIHNldCBlYWNoIHNlcnZlcidzIHRyaWFsIGxlbmd0aCwgYW5kIGNhcCBob3cgbWFueSB0cmlhbHMgb25lIGN1c3RvbWVyIGNhbiB0YWtlLiBUcmlhbHMgcmVxdWlyZSBhIHZlcmlmaWVkIGFjY291bnQgKGVtYWlsICsgV2hhdHNBcHApIGFuZCBhcmUgZW5mb3JjZWQgcGVyIGN1c3RvbWVyIGlkZW50aXR5LjwvcD4KPCUgaWYgKGZsYXNoKSB7ICU+PGRpdiBjbGFzcz0iZmxhc2giPjwlPSBmbGFzaCAlPjwvZGl2PjwlIH0gJT4KPCUgcm93cy5mb3JFYWNoKGZ1bmN0aW9uKHIpeyAlPjxmb3JtIGlkPSJ0Zl88JT0gci5za3UgJT4iIG1ldGhvZD0icG9zdCIgYWN0aW9uPSIvYWRtaW4vdHJpYWxzL3NhdmUiPjwvZm9ybT48JSB9KTsgJT4KPGRpdiBjbGFzcz0iY2FyZCIgc3R5bGU9InBhZGRpbmc6MDtvdmVyZmxvdzpoaWRkZW4iPgogIDx0YWJsZT4KICAgIDx0aGVhZD48dHI+PHRoPklQVFYgc2VydmVyPC90aD48dGggc3R5bGU9IndpZHRoOjgwcHgiPlRyaWFsczwvdGg+PHRoPkR1cmF0aW9uIGxhYmVsPC90aD48dGggc3R5bGU9IndpZHRoOjEwMHB4Ij5Ib3VyczwvdGg+PHRoIHN0eWxlPSJ3aWR0aDoxMzBweCI+TWF4IC8gY3VzdG9tZXI8L3RoPjx0aCBzdHlsZT0id2lkdGg6OTBweCI+PC90aD48L3RyPjwvdGhlYWQ+CiAgICA8dGJvZHk+CiAgICA8JSByb3dzLmZvckVhY2goZnVuY3Rpb24ocil7ICU+CiAgICAgIDx0cj4KICAgICAgICA8dGQ+CiAgICAgICAgICA8Yj48JT0gci5uYW1lICU+PC9iPgogICAgICAgICAgPGRpdiBzdHlsZT0iY29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMnB4Ij48JT0gci5za3UgJT48L2Rpdj4KICAgICAgICAgIDxpbnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9InNrdSIgdmFsdWU9IjwlPSByLnNrdSAlPiIgZm9ybT0idGZfPCU9IHIuc2t1ICU+Ij4KICAgICAgICA8L3RkPgogICAgICAgIDx0ZD4KICAgICAgICAgIDxsYWJlbCBzdHlsZT0iZGlzcGxheTppbmxpbmUtZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjhweDtmb250LXdlaWdodDo2MDAiPgogICAgICAgICAgICA8aW5wdXQgdHlwZT0iY2hlY2tib3giIG5hbWU9ImVuYWJsZWQiIHZhbHVlPSIxIiBmb3JtPSJ0Zl88JT0gci5za3UgJT4iIDwlPSByLmVuYWJsZWQgPyAnY2hlY2tlZCcgOiAnJyAlPiBzdHlsZT0id2lkdGg6YXV0bzttYXJnaW46MCI+T24KICAgICAgICAgIDwvbGFiZWw+CiAgICAgICAgPC90ZD4KICAgICAgICA8dGQ+PGlucHV0IHR5cGU9InRleHQiIG5hbWU9ImR1cmF0aW9uX2xhYmVsIiB2YWx1ZT0iPCU9IHIuZHVyYXRpb25fbGFiZWwgfHwgJycgJT4iIHBsYWNlaG9sZGVyPSJlLmcuIDI0LWhvdXIgdHJpYWwiIGZvcm09InRmXzwlPSByLnNrdSAlPiIgc3R5bGU9Im1hcmdpbjowIj48L3RkPgogICAgICAgIDx0ZD48aW5wdXQgdHlwZT0ibnVtYmVyIiBuYW1lPSJkdXJhdGlvbl9ob3VycyIgdmFsdWU9IjwlPSAoci5kdXJhdGlvbl9ob3Vycz09bnVsbD8yNDpyLmR1cmF0aW9uX2hvdXJzKSAlPiIgbWluPSIxIiBtYXg9IjIxNjAiIGZvcm09InRmXzwlPSByLnNrdSAlPiIgc3R5bGU9Im1hcmdpbjowIj48L3RkPgogICAgICAgIDx0ZD48aW5wdXQgdHlwZT0ibnVtYmVyIiBuYW1lPSJtYXhfcGVyX2N1c3RvbWVyIiB2YWx1ZT0iPCU9IChyLm1heF9wZXJfY3VzdG9tZXI9PW51bGw/MTpyLm1heF9wZXJfY3VzdG9tZXIpICU+IiBtaW49IjEiIG1heD0iOTkiIGZvcm09InRmXzwlPSByLnNrdSAlPiIgc3R5bGU9Im1hcmdpbjowIj48L3RkPgogICAgICAgIDx0ZCBzdHlsZT0idGV4dC1hbGlnbjpyaWdodCI+PGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1wIiB0eXBlPSJzdWJtaXQiIGZvcm09InRmXzwlPSByLnNrdSAlPiI+U2F2ZTwvYnV0dG9uPjwvdGQ+CiAgICAgIDwvdHI+CiAgICA8JSB9KTsgJT4KICAgIDwvdGJvZHk+CiAgPC90YWJsZT4KPC9kaXY+CjwlIGlmICghcm93cy5sZW5ndGgpIHsgJT48ZGl2IGNsYXNzPSJjYXJkIj5ObyBJUFRWIHNlcnZlcnMgZm91bmQgaW4gYm90IG1hcHBpbmcuIE9uY2UgSVBUViBwcm9kdWN0cyBhcmUgbWFwcGVkIChkZWxpdmVyeSB0eXBlIDxiPmlwdHY8L2I+KSwgdGhleSdsbCBhcHBlYXIgaGVyZS48L2Rpdj48JSB9ICU+CjwlLSBpbmNsdWRlKCdfc2hlbGxfYm90dG9tJykgJT4K
B64

echo "==> patch lib/botapi.js (generateTrial)"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/lib/botapi.js'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf('generateTrial')>=0){ console.log('   botapi already'); }
else {
  const a="function validateMac(mac) { return req('GET', '/api/validate-mac/' + encodeURIComponent(mac), null, 8000); }";
  if(s.indexOf(a)<0){ console.error('!! botapi validateMac anchor not found'); process.exit(2); }
  s=s.replace(a, a+"\nfunction generateTrial(payload) { return req('POST', '/api/generate-trial', payload, 15000); }");
  const e=", clearCache };";
  if(s.indexOf(e)<0){ console.error('!! botapi export anchor not found'); process.exit(3); }
  s=s.replace(e, ", clearCache, generateTrial };");
  fs.writeFileSync(f,s); console.log('   botapi patched');
}
NODE

echo "==> patch server.js (mount adminTrials)"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/server.js'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf('adminTrials')>=0){ console.log('   server already'); }
else {
  const a="const adminMappingRouter = require('./routes/adminMapping')(pool);\napp.use('/admin', adminMappingRouter);";
  if(s.indexOf(a)<0){ console.error('!! adminMapping mount anchor not found'); process.exit(4); }
  s=s.replace(a, a+"\nconst adminTrialsRouter = require('./routes/adminTrials')(pool);\napp.use('/admin', adminTrialsRouter);");
  fs.writeFileSync(f,s); console.log('   server patched');
}
NODE

echo "==> patch admin nav (Trials link)"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/views/admin/_shell_top.ejs'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf("on('trials')")>=0){ console.log('   nav already'); }
else {
  const a='<path d="M8 12h8"/></svg>Bot mapping</a>';
  if(s.indexOf(a)<0){ console.error('!! mapping nav anchor not found'); process.exit(5); }
  const link=a+"\n    <a href=\"/admin/trials\" class=\"<%= on('trials') %>\"><svg viewBox=\"0 0 24 24\"><circle cx=\"12\" cy=\"12\" r=\"3.2\"/><path d=\"M12 2v3\"/><path d=\"M12 19v3\"/><path d=\"M2 12h3\"/><path d=\"M19 12h3\"/></svg>Trials</a>";
  s=s.replace(a, link); fs.writeFileSync(f,s); console.log('   nav patched');
}
NODE

echo "==> node --check + ejs compile + restart"
node --check "$APP/routes/adminTrials.js"; node --check "$APP/lib/botapi.js"; node --check "$APP/server.js"
node -e "const ejs=require('ejs'),fs=require('fs');['views/admin/trials.ejs','views/admin/_shell_top.ejs'].forEach(v=>{ejs.compile(fs.readFileSync('$APP/'+v,'utf8'),{filename:'$APP/'+v});});console.log('   views compile');"
pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }
C1=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:3900/admin/trials || true)
[ "$C1" = "302" ] || { echo "!! /admin/trials should redirect to admin login (got $C1)"; false; }
trap - ERR
echo "==> step91 OK — Trials admin live at /admin/trials. Backup: $BAK"
echo "   Enable trials per IPTV server, set duration + max per customer. Claim flow (4b) next."
