#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
F="$GSZ/views/account/signup.ejs"
TS=$(date +%Y%m%d-%H%M%S)
BK="$F.bak-step154-$TS"
echo "==> step154: compact Create-Account popup + country order (Name · +code)"
[ -f "$F" ] || { echo "!! $F not found"; exit 1; }

if grep -q '/\*suCompact\*/' "$F"; then
  echo "    skip (already applied)"; 
else
  cp "$F" "$BK"; echo "    backup: $BK"
  TMP=$(mktemp /tmp/signup.XXXXXX.ejs)
  echo "PCUtIGluY2x1ZGUoJy4uL3BhcnRpYWxzL3N0b3JlX3RvcCcpICU+CjwlLSBpbmNsdWRlKCcuLi9wYXJ0aWFscy9hdXRoX3N0eWxlJykgJT4KPG1haW4gY2xhc3M9ImF1dGgiPgogIDxkaXYgY2xhc3M9IndyYXAiIHN0eWxlPSJkaXNwbGF5OmZsZXg7anVzdGlmeS1jb250ZW50OmNlbnRlciI+CiAgICA8ZGl2IGNsYXNzPSJhdXRoLWNhcmQgc3UiPgogICAgICA8c3R5bGU+LypzdUNvbXBhY3QqLwogICAgICAgIC5zdSAubGVhZHttYXJnaW46MCAwIDE1cHg7Zm9udC1zaXplOjE0cHh9CiAgICAgICAgLnN1IC5mbGR7bWFyZ2luOjAgMCA1cHh9CiAgICAgICAgLnN1IGlucHV0e21hcmdpbjowIDAgMTFweH0KICAgICAgICAuc3UgLnN1LWdyaWQye2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6MWZyIDFmcjtnYXA6MCAxMnB4fQogICAgICAgIC5zdSAud2Etcm93e2Rpc3BsYXk6ZmxleDtnYXA6OHB4O2FsaWduLWl0ZW1zOmNlbnRlcjttYXJnaW46MCAwIDZweH0KICAgICAgICAuc3UgLndhLXJvdyBzZWxlY3R7bWF4LXdpZHRoOjE1MHB4O21hcmdpbjowO3RleHQtb3ZlcmZsb3c6ZWxsaXBzaXN9CiAgICAgICAgLnN1IC53YS1yb3cgaW5wdXR7ZmxleDoxO21hcmdpbjowfQogICAgICAgIC5zdSAuaGludHttYXJnaW46MCAwIDEycHh9CiAgICAgICAgQG1lZGlhKG1heC13aWR0aDo0NjBweCl7IC5zdSAuc3UtZ3JpZDJ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmcn0gfQogICAgICA8L3N0eWxlPgogICAgICA8c3BhbiBjbGFzcz0iYXV0aC1iYWRnZSI+PHNwYW4gY2xhc3M9ImRvdCI+PC9zcGFuPkNyZWF0ZSB5b3VyIGFjY291bnQ8L3NwYW4+CiAgICAgIDxoMT5TaWduIHVwPC9oMT4KICAgICAgPHAgY2xhc3M9ImxlYWQiPk9uZSBhY2NvdW50IGZvciB5b3VyIG9yZGVycywgZG93bmxvYWRzIGFuZCBmcmVlIHRyaWFscy48L3A+CiAgICAgIDwlIGlmIChlcnJvcikgeyAlPjxkaXYgY2xhc3M9ImVyciI+PCU9IGVycm9yICU+PC9kaXY+PCUgfSAlPgogICAgICA8Zm9ybSBtZXRob2Q9InBvc3QiIGFjdGlvbj0iL3NpZ251cCIgYXV0b2NvbXBsZXRlPSJvbiI+CiAgICAgICAgPGRpdiBjbGFzcz0ic3UtZ3JpZDIiPgogICAgICAgICAgPGRpdj4KICAgICAgICAgICAgPGxhYmVsIGNsYXNzPSJmbGQiIGZvcj0ibmFtZSI+RnVsbCBuYW1lPC9sYWJlbD4KICAgICAgICAgICAgPGlucHV0IGlkPSJuYW1lIiB0eXBlPSJ0ZXh0IiBuYW1lPSJuYW1lIiB2YWx1ZT0iPCU9IGZvcm0ubmFtZSB8fCAnJyAlPiIgcGxhY2Vob2xkZXI9IllvdXIgbmFtZSIgcmVxdWlyZWQgYXV0b2NvbXBsZXRlPSJuYW1lIj4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPGRpdj4KICAgICAgICAgICAgPGxhYmVsIGNsYXNzPSJmbGQiIGZvcj0iZW1haWwiPkVtYWlsIGFkZHJlc3M8L2xhYmVsPgogICAgICAgICAgICA8aW5wdXQgaWQ9ImVtYWlsIiB0eXBlPSJlbWFpbCIgbmFtZT0iZW1haWwiIHZhbHVlPSI8JT0gZm9ybS5lbWFpbCB8fCAnJyAlPiIgcGxhY2Vob2xkZXI9InlvdUBlbWFpbC5jb20iIHJlcXVpcmVkIGF1dG9jb21wbGV0ZT0iZW1haWwiPgogICAgICAgICAgPC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPGxhYmVsIGNsYXNzPSJmbGQiIGZvcj0id2EiPldoYXRzQXBwIG51bWJlcjwvbGFiZWw+CiAgICAgICAgPGRpdiBjbGFzcz0id2Etcm93Ij4KICAgICAgICAgIDxzZWxlY3QgbmFtZT0id2FfY291bnRyeSIgaWQ9IndhX2NvdW50cnkiPgogICAgICAgICAgICA8JSB2YXIgc2VsQ3QgPSAoZm9ybS53YV9jb3VudHJ5IHx8ICdQSycpOyAodHlwZW9mIGNvdW50cmllcyE9PSd1bmRlZmluZWQnP2NvdW50cmllczpbXSkuZm9yRWFjaChmdW5jdGlvbihjdCl7ICU+PG9wdGlvbiB2YWx1ZT0iPCU9IGN0LmlzbyAlPiIgPCU9IGN0Lmlzbz09PXNlbEN0PydzZWxlY3RlZCc6JycgJT4+PCU9IGN0Lm5hbWUgJT4gwrcgKzwlPSBjdC5jb2RlICU+PC9vcHRpb24+PCUgfSk7ICU+CiAgICAgICAgICA8L3NlbGVjdD4KICAgICAgICAgIDxpbnB1dCBpZD0id2EiIHR5cGU9InRlbCIgbmFtZT0id2EiIHZhbHVlPSI8JT0gZm9ybS53YSB8fCAnJyAlPiIgcGxhY2Vob2xkZXI9IjMwMCAxMjM0NTY3IiByZXF1aXJlZCBhdXRvY29tcGxldGU9InRlbCI+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPHAgY2xhc3M9ImhpbnQiPkxvY2FsIGZvcm1hdCBpcyBmaW5lIOKAlCB5b3UnbGwgdmVyaWZ5IGl0IG9uIFdoYXRzQXBwLjwvcD4KICAgICAgICA8ZGl2IGNsYXNzPSJzdS1ncmlkMiI+CiAgICAgICAgICA8ZGl2PgogICAgICAgICAgICA8bGFiZWwgY2xhc3M9ImZsZCIgZm9yPSJwYXNzd29yZCI+UGFzc3dvcmQ8L2xhYmVsPgogICAgICAgICAgICA8aW5wdXQgaWQ9InBhc3N3b3JkIiB0eXBlPSJwYXNzd29yZCIgbmFtZT0icGFzc3dvcmQiIHBsYWNlaG9sZGVyPSJBdCBsZWFzdCA4IGNoYXJhY3RlcnMiIHJlcXVpcmVkIGF1dG9jb21wbGV0ZT0ibmV3LXBhc3N3b3JkIj4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPGRpdj4KICAgICAgICAgICAgPGxhYmVsIGNsYXNzPSJmbGQiIGZvcj0icGFzc3dvcmQyIj5Db25maXJtIHBhc3N3b3JkPC9sYWJlbD4KICAgICAgICAgICAgPGlucHV0IGlkPSJwYXNzd29yZDIiIHR5cGU9InBhc3N3b3JkIiBuYW1lPSJwYXNzd29yZDIiIHBsYWNlaG9sZGVyPSJSZS1lbnRlciBwYXNzd29yZCIgcmVxdWlyZWQgYXV0b2NvbXBsZXRlPSJuZXctcGFzc3dvcmQiPgogICAgICAgICAgPC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgICAgPGJ1dHRvbiBjbGFzcz0iYnRuIGJ0bi1wIGJ0bi1mdWxsIiB0eXBlPSJzdWJtaXQiPkNyZWF0ZSBhY2NvdW50PC9idXR0b24+CiAgICAgIDwvZm9ybT4KICAgICAgPHAgY2xhc3M9ImFsdCI+QWxyZWFkeSBoYXZlIGFuIGFjY291bnQ/IDxhIGhyZWY9Ii9sb2dpbiI+U2lnbiBpbjwvYT48L3A+CiAgICA8L2Rpdj4KICA8L2Rpdj4KPC9tYWluPgo8JS0gaW5jbHVkZSgnLi4vcGFydGlhbHMvc3RvcmVfYm90dG9tJykgJT4K" | base64 -d > "$TMP"
  # validate the NEW file compiles before swapping in
  NODE_PATH="$GSZ/node_modules" node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$TMP','utf8'),{filename:'$TMP',compileDebug:false});console.log('    new signup.ejs compiles')"
  mv "$TMP" "$F"
  echo "    written"
fi

echo "==> validating in place"
NODE_PATH="$GSZ/node_modules" node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$F','utf8'),{filename:'$F'});console.log('    ejs ok')"

echo "==> restarting"
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000
for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    homepage $CODE after ${i}s"; exit 1; }
echo "    homepage 200: OK (after ${i}s)"
echo ""
echo "==> step154 OK  Sign-up is now a tight 2-column layout (name|email, password|confirm) that fits the popup without scrolling and stacks on phones. Country dropdown now reads 'Pakistan · +92'. Hard-refresh once."
