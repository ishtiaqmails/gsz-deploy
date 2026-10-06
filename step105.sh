#!/usr/bin/env bash
# step105 — Batch 3: admin editor for bot messages. /admin/messages lets you edit
# every WhatsApp message per language and toggle which languages are sent.
# Adds the route + view, mounts it, and adds the nav link. Idempotent; rollback.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step105-$TS
mkdir -p "$BAK" "$BAK/views/admin"
cp "$APP/server.js" "$BAK/server.js"
cp "$APP/views/admin/_shell_top.ejs" "$BAK/views/admin/_shell_top.ejs"
restore(){ echo "!! rollback"; cp "$BAK/server.js" "$APP/server.js"; cp "$BAK/views/admin/_shell_top.ejs" "$APP/views/admin/_shell_top.ejs"; rm -f "$APP/routes/adminMessages.js" "$APP/views/admin/messages.ejs"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR
cd "$APP"

echo "==> write route + view"
base64 -d > "$APP/routes/adminMessages.js" <<'B64'
Y29uc3QgZXhwcmVzcyA9IHJlcXVpcmUoJ2V4cHJlc3MnKTsKCm1vZHVsZS5leHBvcnRzID0gZnVuY3Rpb24gKHBvb2wpIHsKICBjb25zdCByb3V0ZXIgPSBleHByZXNzLlJvdXRlcigpOwogIGNvbnN0IGJvZHkgPSBleHByZXNzLnVybGVuY29kZWQoeyBleHRlbmRlZDogdHJ1ZSwgbGltaXQ6ICcyNTZrYicgfSk7CiAgZnVuY3Rpb24gYXV0aChyZXEsIHJlcywgbmV4dCkgeyBpZiAocmVxLnNlc3Npb24gJiYgcmVxLnNlc3Npb24uYWRtaW4pIHJldHVybiBuZXh0KCk7IHJldHVybiByZXMucmVkaXJlY3QoJy9hZG1pbi9sb2dpbicpOyB9CgogIGNvbnN0IE5BTUVTID0gewogICAgJ3doYXRzYXBwLnZlcmlmaWNhdGlvbl9zdWNjZXNzJzogJ1doYXRzQXBwIHZlcmlmaWVkJywKICAgICd3aGF0c2FwcC5vcmRlcl9yZWNlaXZlZCc6ICdPcmRlciByZWNlaXZlZCcsCiAgICAnd2hhdHNhcHAucGF5bWVudF9jb25maXJtZWQnOiAnUGF5bWVudCBjb25maXJtZWQnLAogICAgJ3doYXRzYXBwLm9yZGVyX2NvbXBsZXRlZCc6ICdPcmRlciBjb21wbGV0ZWQnLAogICAgJ3doYXRzYXBwLmNyZWRlbnRpYWxzJzogJ0NyZWRlbnRpYWxzIHJlYWR5JywKICAgICd3aGF0c2FwcC50cmlhbF9yZWFkeSc6ICdUcmlhbCByZWFkeScsCiAgICAnd2hhdHNhcHAucGFzc3dvcmRfcmVzZXQnOiAnUGFzc3dvcmQgcmVzZXQgY29kZScsCiAgICAnd2hhdHNhcHAuc3Vic2NyaXB0aW9uX2V4cGlyeSc6ICdTdWJzY3JpcHRpb24gZXhwaXJ5JywKICAgICd3aGF0c2FwcC5yZWRpcmVjdF9zdXBwb3J0JzogJ1ZlcmlmaWNhdGlvbi1udW1iZXIgYXV0by1yZXBseScsCiAgICAnd2hhdHNhcHAubnVtYmVyX2NoYW5nZSc6ICdXaGF0c0FwcCBudW1iZXIgY2hhbmdlZCcsCiAgICAnd2hhdHNhcHAuc2VjdXJpdHlfYWxlcnQnOiAnU2VjdXJpdHkgYWxlcnQnLAogICAgJ3doYXRzYXBwLnRlc3QnOiAnVGVzdCBtZXNzYWdlJwogIH07CiAgY29uc3QgTEFOR1MgPSBbeyBjb2RlOiAnZW4nLCBuYW1lOiAnRW5nbGlzaCcsIHJ0bDogZmFsc2UgfSwgeyBjb2RlOiAndXInLCBuYW1lOiAnVXJkdScsIHJ0bDogdHJ1ZSB9LCB7IGNvZGU6ICdhcicsIG5hbWU6ICdBcmFiaWMnLCBydGw6IHRydWUgfSwgeyBjb2RlOiAncm8nLCBuYW1lOiAnUm9tYW4gVXJkdScsIHJ0bDogZmFsc2UgfV07CgogIHJvdXRlci5nZXQoJy9tZXNzYWdlcycsIGF1dGgsIGFzeW5jIChyZXEsIHJlcykgPT4gewogICAgY29uc3Qgcm93cyA9IChhd2FpdCBwb29sLnF1ZXJ5KCdTRUxFQ1Qga2V5LCBib2R5LCBsYW5ncyBGUk9NIHdhX3RlbXBsYXRlcyBPUkRFUiBCWSBrZXknKSkucm93czsKICAgIGNvbnN0IGVuYWJsZWQgPSAoKChhd2FpdCBwb29sLnF1ZXJ5KCJTRUxFQ1QgdmFsdWUgRlJPTSB3YV9zZXR0aW5ncyBXSEVSRSBrZXk9J3dhX2xhbmdzJyIpKS5yb3dzWzBdIHx8IHt9KS52YWx1ZSB8fCAnZW4nKS5zcGxpdCgnLCcpLm1hcCh4ID0+IHgudHJpbSgpKS5maWx0ZXIoQm9vbGVhbik7CiAgICByZXMucmVuZGVyKCdhZG1pbi9tZXNzYWdlcycsIHsgcm93cywgbmFtZXM6IE5BTUVTLCBsYW5nczogTEFOR1MsIGVuYWJsZWQsIGZsYXNoOiByZXEucXVlcnkub2sgfHwgbnVsbCB9KTsKICB9KTsKCiAgcm91dGVyLnBvc3QoJy9tZXNzYWdlcy9sYW5ncycsIGF1dGgsIGJvZHksIGFzeW5jIChyZXEsIHJlcykgPT4gewogICAgY29uc3Qgc2VsID0gW10uY29uY2F0KHJlcS5ib2R5LmxhbmcgfHwgW10pLmZpbHRlcihCb29sZWFuKTsKICAgIGNvbnN0IHZhbCA9IChzZWwubGVuZ3RoID8gc2VsIDogWydlbiddKS5qb2luKCcsJyk7CiAgICBhd2FpdCBwb29sLnF1ZXJ5KCJJTlNFUlQgSU5UTyB3YV9zZXR0aW5ncyhrZXksdmFsdWUpIFZBTFVFUygnd2FfbGFuZ3MnLCQxKSBPTiBDT05GTElDVChrZXkpIERPIFVQREFURSBTRVQgdmFsdWU9JDEsIHVwZGF0ZWRfYXQ9bm93KCkiLCBbdmFsXSk7CiAgICByZXMucmVkaXJlY3QoJy9hZG1pbi9tZXNzYWdlcz9vaz1MYW5ndWFnZXMrdXBkYXRlZCcpOwogIH0pOwoKICByb3V0ZXIucG9zdCgnL21lc3NhZ2VzL3NhdmUnLCBhdXRoLCBib2R5LCBhc3luYyAocmVxLCByZXMpID0+IHsKICAgIGNvbnN0IGtleSA9IChyZXEuYm9keS5rZXkgfHwgJycpLnRyaW0oKTsgaWYgKCFrZXkpIHJldHVybiByZXMucmVkaXJlY3QoJy9hZG1pbi9tZXNzYWdlcycpOwogICAgY29uc3QgbGFuZ3MgPSB7fTsKICAgIFsnZW4nLCAndXInLCAnYXInLCAncm8nXS5mb3JFYWNoKGNvZGUgPT4geyBjb25zdCB2ID0gcmVxLmJvZHlbJ2xhbmdfJyArIGNvZGVdOyBpZiAodiAhPSBudWxsICYmIFN0cmluZyh2KS50cmltKCkgIT09ICcnKSBsYW5nc1tjb2RlXSA9IFN0cmluZyh2KTsgfSk7CiAgICBhd2FpdCBwb29sLnF1ZXJ5KCJVUERBVEUgd2FfdGVtcGxhdGVzIFNFVCBsYW5ncz0kMiwgYm9keT1DT0FMRVNDRSgkMywgYm9keSksIHVwZGF0ZWRfYXQ9bm93KCkgV0hFUkUga2V5PSQxIiwgW2tleSwgSlNPTi5zdHJpbmdpZnkobGFuZ3MpLCBsYW5ncy5lbiB8fCBudWxsXSk7CiAgICByZXMucmVkaXJlY3QoJy9hZG1pbi9tZXNzYWdlcz9vaz0nICsgZW5jb2RlVVJJQ29tcG9uZW50KCdTYXZlZDogJyArIChOQU1FU1trZXldIHx8IGtleSkpKTsKICB9KTsKCiAgcmV0dXJuIHJvdXRlcjsKfTsK
B64
base64 -d > "$APP/views/admin/messages.ejs" <<'B64'
PCUtIGluY2x1ZGUoJ19zaGVsbF90b3AnLCB7IGFjdGl2ZTonbWVzc2FnZXMnLCB0aXRsZTonQm90IG1lc3NhZ2VzJyB9KSAlPgo8cCBjbGFzcz0ic3ViIj5FZGl0IGV2ZXJ5IFdoYXRzQXBwIG1lc3NhZ2UgeW91ciBib3Qgc2VuZHMsIGluIGVhY2ggbGFuZ3VhZ2UuIEVuYWJsZWQgbGFuZ3VhZ2VzIGFyZSBzZW50IHRvZ2V0aGVyIGluIG9uZSBtZXNzYWdlLiBVc2UgPGNvZGU+e3sne3snfX12YXJpYWJsZXt7J319J319PC9jb2RlPiBwbGFjZWhvbGRlcnMgKGUuZy4gPGNvZGU+e3sne3snfX1vcmRlcl9udW1iZXJ7eyd9fSd9fTwvY29kZT4pIOKAlCB0aGV5J3JlIGZpbGxlZCBpbiBhdXRvbWF0aWNhbGx5LjwvcD4KPCUgaWYgKGZsYXNoKSB7ICU+PGRpdiBjbGFzcz0iZmxhc2giPjwlPSBmbGFzaCAlPjwvZGl2PjwlIH0gJT4KCjxkaXYgY2xhc3M9ImNhcmQiPgogIDxoMiBzdHlsZT0ibWFyZ2luLWJvdHRvbToxMnB4Ij5MYW5ndWFnZXMgc2VudCBpbiBlYWNoIG1lc3NhZ2U8L2gyPgogIDxmb3JtIG1ldGhvZD0icG9zdCIgYWN0aW9uPSIvYWRtaW4vbWVzc2FnZXMvbGFuZ3MiIHN0eWxlPSJkaXNwbGF5OmZsZXg7Z2FwOjE4cHg7ZmxleC13cmFwOndyYXA7YWxpZ24taXRlbXM6Y2VudGVyIj4KICAgIDwlIGxhbmdzLmZvckVhY2goZnVuY3Rpb24obCl7ICU+CiAgICAgIDxsYWJlbCBzdHlsZT0iZGlzcGxheTppbmxpbmUtZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjhweDtmb250LXdlaWdodDo2MDAiPjxpbnB1dCB0eXBlPSJjaGVja2JveCIgbmFtZT0ibGFuZyIgdmFsdWU9IjwlPSBsLmNvZGUgJT4iIDwlPSBlbmFibGVkLmluZGV4T2YobC5jb2RlKT49MD8nY2hlY2tlZCc6JycgJT4gc3R5bGU9IndpZHRoOmF1dG87bWFyZ2luOjAiPjwlPSBsLm5hbWUgJT48L2xhYmVsPgogICAgPCUgfSk7ICU+CiAgICA8YnV0dG9uIGNsYXNzPSJidG4gYnRuLXAiIHR5cGU9InN1Ym1pdCIgc3R5bGU9Im1hcmdpbi1sZWZ0OmF1dG8iPlNhdmUgbGFuZ3VhZ2VzPC9idXR0b24+CiAgPC9mb3JtPgogIDxwIGNsYXNzPSJoaW50IiBzdHlsZT0ibWFyZ2luLXRvcDoxMHB4Ij5UaXA6IG1vcmUgbGFuZ3VhZ2VzID0gbG9uZ2VyIG1lc3NhZ2VzLiBFbmdsaXNoICsgVXJkdSBpcyBhIGdvb2QgZGVmYXVsdCBmb3IgbW9zdCBjdXN0b21lcnMuPC9wPgo8L2Rpdj4KCjwlIHJvd3MuZm9yRWFjaChmdW5jdGlvbihyKXsgdmFyIEwgPSAoci5sYW5ncyAmJiB0eXBlb2Ygci5sYW5ncz09PSdvYmplY3QnKSA/IHIubGFuZ3MgOiB7fTsgJT4KICA8ZGl2IGNsYXNzPSJjYXJkIj4KICAgIDxkaXYgc3R5bGU9ImRpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpiYXNlbGluZTtnYXA6MTBweDtmbGV4LXdyYXA6d3JhcDttYXJnaW4tYm90dG9tOjEwcHgiPgogICAgICA8aDIgc3R5bGU9Im1hcmdpbjowIj48JT0gbmFtZXNbci5rZXldIHx8IHIua2V5ICU+PC9oMj4KICAgICAgPGNvZGUgc3R5bGU9ImNvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTJweCI+PCU9IHIua2V5ICU+PC9jb2RlPgogICAgPC9kaXY+CiAgICA8Zm9ybSBtZXRob2Q9InBvc3QiIGFjdGlvbj0iL2FkbWluL21lc3NhZ2VzL3NhdmUiPgogICAgICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJrZXkiIHZhbHVlPSI8JT0gci5rZXkgJT4iPgogICAgICA8JSBsYW5ncy5mb3JFYWNoKGZ1bmN0aW9uKGwpeyB2YXIgdmFsID0gKExbbC5jb2RlXSE9bnVsbCk/TFtsLmNvZGVdOihsLmNvZGU9PT0nZW4nPyhyLmJvZHl8fCcnKTonJyk7ICU+CiAgICAgICAgPGxhYmVsIGNsYXNzPSJmbGQiPjwlPSBsLm5hbWUgJT48JSBpZiAoZW5hYmxlZC5pbmRleE9mKGwuY29kZSk8MCkgeyAlPiA8c3BhbiBzdHlsZT0iY29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtd2VpZ2h0OjUwMCI+KG5vdCBjdXJyZW50bHkgc2VudCk8L3NwYW4+PCUgfSAlPjwvbGFiZWw+CiAgICAgICAgPHRleHRhcmVhIG5hbWU9ImxhbmdfPCU9IGwuY29kZSAlPiIgcm93cz0iMiIgPCU9IGwucnRsPydkaXI9InJ0bCInOicnICU+IHN0eWxlPSJtYXJnaW4tYm90dG9tOjEycHgiPjwlPSB2YWwgJT48L3RleHRhcmVhPgogICAgICA8JSB9KTsgJT4KICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1wIiB0eXBlPSJzdWJtaXQiPlNhdmUgbWVzc2FnZTwvYnV0dG9uPgogICAgPC9mb3JtPgogIDwvZGl2Pgo8JSB9KTsgJT4KPCUtIGluY2x1ZGUoJ19zaGVsbF9ib3R0b20nKSAlPgo=
B64

echo "==> mount adminMessages in server.js"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/server.js'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf('adminMessages')>=0){ console.log('   server already'); }
else {
  const a="const adminTrialsRouter = require('./routes/adminTrials')(pool);\napp.use('/admin', adminTrialsRouter);";
  if(s.indexOf(a)<0){ console.error('!! adminTrials mount anchor not found'); process.exit(2); }
  s=s.replace(a, a+"\nconst adminMessagesRouter = require('./routes/adminMessages')(pool);\napp.use('/admin', adminMessagesRouter);");
  fs.writeFileSync(f,s); console.log('   server patched');
}
NODE

echo "==> add nav link"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/views/admin/_shell_top.ejs'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf("on('messages')")>=0){ console.log('   nav already'); }
else {
  const a='</svg>Trials</a>';
  if(s.indexOf(a)<0){ console.error('!! Trials nav anchor not found'); process.exit(3); }
  s=s.replace(a, a+"\n    <a href=\"/admin/messages\" class=\"<%= on('messages') %>\"><svg viewBox=\"0 0 24 24\"><path d=\"M4 5h16v10H9l-4 4V5z\"/></svg>Bot messages</a>");
  fs.writeFileSync(f,s); console.log('   nav patched');
}
NODE

echo "==> node --check + ejs compile + restart"
node --check "$APP/routes/adminMessages.js"; node --check "$APP/server.js"
node -e "const ejs=require('ejs'),fs=require('fs');['views/admin/messages.ejs','views/admin/_shell_top.ejs'].forEach(v=>{ejs.compile(fs.readFileSync('$APP/'+v,'utf8'),{filename:'$APP/'+v});});console.log('   views compile');"
pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }
C1=$(curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:3900/admin/messages || true)
[ "$C1" = "302" ] || { echo "!! /admin/messages should redirect to admin login (got $C1)"; false; }
trap - ERR
echo "==> step105 OK — Bot messages editor live at /admin/messages. Backup: $BAK"
