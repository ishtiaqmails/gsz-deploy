#!/usr/bin/env bash
# dumpTrialState — exact status + error for each recent trial claim (read-only).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
echo "########## recent trial claims (status + error/cred) ##########"
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c \
"SELECT id, trial_type AS sku, server_name, status,
        left(coalesce(bot_ref,''),60)      AS ref_or_error,
        left(coalesce(credentials,''),40)  AS cred_preview,
        claimed_at::timestamp(0)           AS at
 FROM trial_claims ORDER BY id DESC LIMIT 16" 2>&1
echo
echo "########## status tally ##########"
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c "SELECT status, count(*) FROM trial_claims GROUP BY status ORDER BY 2 DESC" 2>&1
echo "== dumpTrialState done =="
