#!/usr/bin/env bash
# dumpWaOutbox — why 4 trial messages didn't send. Outbox schema + trial rows + poller delivery code.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "########## wa_notifications schema ##########"
Q -c "\d wa_notifications" | sed -n '1,40p'
echo
echo "########## recent outbox rows (all) ##########"
Q -c "SELECT * FROM wa_notifications ORDER BY id DESC LIMIT 16" 2>&1
echo
echo "########## trial_ready rows specifically ##########"
Q -c "SELECT * FROM wa_notifications WHERE template_key LIKE '%trial%' ORDER BY id DESC LIMIT 12" 2>&1
echo
echo "########## lib/wanotify.js (how enqueue + send works) ##########"
sed -n '1,120p' lib/wanotify.js 2>&1
echo "== dumpWaOutbox done =="
