#!/usr/bin/env bash
# diagServerStatus — what server/panel status data is available to the WEBSITES (zayron health module, galaxyzayron
# IPTV status, bridge endpoints), to show live server status on zayron auto-synced from the reseller bot. READ-ONLY.
set +e
echo "########## zayron: lib/admin/health.js (what it monitors + how) ##########"
cd /opt/zayron && wc -l lib/admin/health.js 2>/dev/null; sed -n '1,70p' lib/admin/health.js 2>/dev/null
echo
echo "### zayron servers: status + reseller_pid columns + how status is set ###"
grep -rn "servers SET status\|status='online'\|status='offline'\|reseller_pid\|server.*status\|updateServerStatus\|panel.*status" routes lib server.js 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | head -15
echo
echo "########## bridge: any server/panel status endpoint (getStock/ping/status) ##########"
grep -n "ping\|getStock\|status\|panel\|health\|/api/" lib/gszApi.js | head
echo "--- galaxyzayron bridge status-ish endpoints ---"
grep -n "function ping\|function getStock\|panel\|server-status\|/api/stock\|/api/ping\|health" /opt/gsz/lib/botapi.js | head
echo
echo "########## galaxyzayron: any live server/panel status feature (admin or public) ##########"
grep -rn "server status\|Server Status\|panel.*online\|live status\|serverStatus\|statusBadge\|uptime" /opt/gsz/routes /opt/gsz/views 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | head -12
echo
echo "########## reseller-bot bridge base (same for both) ##########"
grep -E '^GSZ_BOT_API_URL=' /opt/zayron/.env | sed 's#\(:[0-9]*\).*#\1#'
echo DONE
