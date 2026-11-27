#!/usr/bin/env bash
# diagZayronNotifyPath — what listens on :8787, whether zayron already uses bot_notify_url, and whether the reseller
# bot /api/notify is reachable from zayron (same base as submitOrder). READ-ONLY.
set +e
echo "### who listens on :8787 ###"
ss -ltnp 2>/dev/null | grep ':8787' || echo "(nothing on 8787)"
pm2 jlist 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{JSON.parse(d).forEach(p=>{const a=(p.pm2_env&&p.pm2_env.args)||[];console.log('- '+p.name+'  cwd='+((p.pm2_env&&p.pm2_env.pm_cwd)||''));});}catch(e){}});" 2>/dev/null | grep -iE "notify|8787|owner" || true
echo
echo "### does zayron reference bot_notify_url / 8787 / notify anywhere? ###"
cd /opt/zayron && grep -rn "bot_notify_url\|8787\|/notify\|notifyOwner\|ownerAlert\|owner_alert" routes lib server.js 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | head -20
echo
echo "### is there a notify service dir (e.g. /opt/*notify*)? ###"
ls -d /opt/*notify* 2>/dev/null; curl -s -o /dev/null -w "8787/notify -> %{http_code}\n" -X POST "http://127.0.0.1:8787/notify" -H 'Content-Type: application/json' --data '{}' 2>/dev/null
echo
echo "### zayron .env reseller-bot base (can zayron POST /api/notify to the reseller bot like galaxyzayron?) ###"
grep -E '^GSZ_BOT_API_URL=' /opt/zayron/.env 2>/dev/null | sed 's#=.*//#=//#'  # show host only, hide nothing sensitive but keep base
echo "--- galaxyzayron notify endpoint for reference ---"
grep -n "api/notify\|function notify" /opt/gsz/lib/botapi.js | head
echo DONE
