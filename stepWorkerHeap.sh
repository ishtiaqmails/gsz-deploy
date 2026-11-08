#!/usr/bin/env bash
# Raise gsz-iptv-worker heap 768 -> 1280 MB so the giant panels (+ get_series) stop OOM-ing.
cd /opt/gsz
echo "reconfiguring gsz-iptv-worker memory..."
pm2 restart gsz-iptv-worker --node-args="--max-old-space-size=1280" --max-memory-restart 1500M --update-env >/dev/null 2>&1
sleep 2
ARGS=$(pm2 describe gsz-iptv-worker 2>/dev/null | grep -i "interpreter args" | grep -o "max-old-space-size=[0-9]*")
if [ "$ARGS" != "max-old-space-size=1280" ]; then
  echo "in-place update did not stick; doing clean delete+start"
  pm2 delete gsz-iptv-worker >/dev/null 2>&1
  pm2 start /opt/gsz/lib/iptv/worker.js --name gsz-iptv-worker --node-args="--max-old-space-size=1280" --max-memory-restart 1500M >/dev/null 2>&1
  sleep 2
fi
pm2 save >/dev/null 2>&1
echo "--- worker config now ---"
pm2 describe gsz-iptv-worker 2>/dev/null | grep -iE "status|interpreter args|max memory restart|uptime|script path"
echo DONE
