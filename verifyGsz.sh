#!/usr/bin/env bash
set +e
echo "### gsz pm2 status ###"
pm2 describe gsz 2>/dev/null | grep -E "status|uptime|restarts|script path" | head
echo
echo "### configured PORT ###"
grep -E '^PORT=' /opt/gsz/.env 2>/dev/null || echo "(no PORT in .env — may default in code)"
echo
echo "### does gsz respond? (try a few ports/paths) ###"
for P in 3900 3901 3000 8080; do
  for PATHX in /healthz /; do
    C=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${P}${PATHX}" 2>/dev/null)
    echo "port ${P} ${PATHX} -> ${C}"
  done
done
echo
echo "### last 18 gsz log lines (startup / errors) ###"
pm2 logs gsz --lines 18 --nostream 2>/dev/null | tail -18
echo DONE
