#!/usr/bin/env bash
# dumpTrials — website IPTV trial flow: claim route, admin setup, tables, fulfilment path.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "$1" 2>&1; }

echo "########## routes/trials.js (full) ##########"; cat routes/trials.js
echo; echo "########## routes/adminTrials.js (full) ##########"; cat routes/adminTrials.js
echo; echo "########## trial_servers schema ##########"; Q "\d trial_servers" | sed -n '1,45p'
echo "--- trial_servers rows (dns/player/panel visible; creds masked) ---"
Q "SELECT id, name, panel, bot_sku, bot_plan_key, bot_type, dns, player, active, (CASE WHEN COALESCE(m3u_template,'')<>'' THEN 'set' ELSE '' END) AS m3u, (CASE WHEN COALESCE(credentials::text,'')<>'' THEN 'set' ELSE '' END) AS creds FROM trial_servers ORDER BY id" 2>&1 | head -40
echo; echo "########## trial_claims schema ##########"; Q "\d trial_claims" | sed -n '1,30p'
echo "--- recent claims ---"; Q "SELECT id, server_id, product_id, status, created_at, (CASE WHEN COALESCE(result,'')<>'' THEN left(result,60) ELSE '' END) AS result FROM trial_claims ORDER BY id DESC LIMIT 10" 2>&1 | head -20
echo; echo "########## how trials provision (grep) ##########"
grep -nE "bot|iptv|panel|dns|player|deliver|provision|forward|axios|fetch|trial_server|m3u|wa_number|sendMessage" routes/trials.js | head -60
echo "== dumpTrials done =="
