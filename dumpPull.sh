cd /opt/gsz
echo "===== pull.js (manual pull tool) ====="
cat -n lib/iptv/pull.js
echo
echo "===== worker.js: exports + sweep cadence + refresh hours ====="
grep -nE "module.exports|setInterval|REFRESH|refresh_hours|iptv_refresh|sweep|staleServers|pullOne|setTimeout|getRefreshHours|enc ?=|require\(" lib/iptv/worker.js
echo
echo "===== pm2 iptv worker process name ====="
pm2 list 2>/dev/null | grep -iE "iptv|worker" || echo "(pm2 list grep empty)"
echo DONE
