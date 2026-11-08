echo "===== RAM ====="
free -m
echo
echo "===== worker pm2 config (script / node args / status / restarts) ====="
pm2 describe gsz-iptv-worker 2>/dev/null | grep -iE "status|restarts|script path|script args|node args|exec cwd|exec mode|unstable|created|uptime|memory|interpreter" | head -30
echo
echo "===== is it crash-looping now? (recent out log) ====="
tail -6 /root/.pm2/logs/gsz-iptv-worker-out.log
echo "--- recent errors (timestamps) ---"
tail -4 /root/.pm2/logs/gsz-iptv-worker-error.log
echo DONE
