#!/usr/bin/env bash
# gsz-sweep23 : read the order-query debug log captured from inside the running
# app, find gsz's real port, then restore the clean (non-logging) engine.
cd /opt/gsz

echo "=== order-query debug log (from inside the app) ==="
cat /opt/gsz/.gsz-ord-debug.log 2>/dev/null || echo "(empty / none)"

echo; echo "=== gsz real listen port ==="
PID=$(pm2 pid gsz 2>/dev/null)
echo "gsz OS pid: $PID"
ss -ltnp 2>/dev/null | grep "pid=$PID," | grep -oE 'LISTEN.*:[0-9]+' | grep -oE ':[0-9]+' | sort -u

echo; echo "=== restoring clean engine ==="
if [ -f /opt/gsz/.gsz-s22-sc.bak ]; then
  cp /opt/gsz/.gsz-s22-sc.bak lib/socialcounts.js
  node --check lib/socialcounts.js && pm2 restart gsz && echo "clean engine restored."
else
  echo "no backup found (engine unchanged)."
fi
