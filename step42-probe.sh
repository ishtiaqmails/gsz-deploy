#!/usr/bin/env bash
# READ ONLY — find where CSS vs JS static files are served from.
APP=/opt/gsz
echo "=== static mounts in server.js ==="
grep -nE "express\.static|/static|use\(" "$APP/server.js" 2>/dev/null | grep -iE "static|css|js|public" | head -40
echo
echo "=== ls public/ ==="; ls -la "$APP/public" 2>/dev/null
echo "=== ls public/css ==="; ls -la "$APP/public/css" 2>/dev/null | head
echo "=== ls public/js ==="; ls -la "$APP/public/js" 2>/dev/null | head
echo "=== where does app.css physically live? ==="
find "$APP" -name 'app.css' -not -path '*/node_modules/*' 2>/dev/null
echo "=== where does app.js (frontend) live? ==="
find "$APP" -name 'app.js' -path '*public*' -not -path '*/node_modules/*' 2>/dev/null
echo "== DONE =="
