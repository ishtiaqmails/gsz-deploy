#!/usr/bin/env bash
# READ-MOSTLY — drop throwaway test files, curl them (no restart), clean up.
APP=/opt/gsz
echo '.gsztest-xyz{color:red}' > "$APP/public/css/__t.css"
echo 'TESTJS_OK' > "$APP/public/js/__t.js"
ls -la "$APP/public/css/__t.css" "$APP/public/js/__t.js"
echo
echo "=== NEW css  /static/css/__t.css ==="
curl -s -o /dev/null -w "HTTP %{http_code}  type=%{content_type}\n" http://127.0.0.1:3900/static/css/__t.css
curl -is http://127.0.0.1:3900/static/css/__t.css | sed -n '1,12p'
echo
echo "=== NEW js   /static/js/__t.js ==="
curl -s -o /dev/null -w "HTTP %{http_code}  type=%{content_type}\n" http://127.0.0.1:3900/static/js/__t.js
echo
echo "=== existing /static/css/app.css ==="
curl -s -o /dev/null -w "HTTP %{http_code}  type=%{content_type}\n" http://127.0.0.1:3900/static/css/app.css
echo
echo "=== does body look like HTML (fallback)? first line of __t.css response ==="
curl -s http://127.0.0.1:3900/static/css/__t.css | head -2
rm -f "$APP/public/css/__t.css" "$APP/public/js/__t.js"
echo "== DONE (test files removed) =="
