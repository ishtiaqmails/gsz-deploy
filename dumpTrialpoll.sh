#!/usr/bin/env bash
# dumpTrialpoll — the delivery poller + what actually happened to the test claims
# + what the bot API returns for each (READ-ONLY; no generation, no credits).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }
KEY="$(grep -E '^GSZ_BOT_API_KEY=' .env | cut -d= -f2-)"
BASE="$(grep -E '^GSZ_BOT_API_URL=' .env | cut -d= -f2- | sed 's#/*$##')"

echo "########## lib/trialpoll.js (full) ##########"; cat lib/trialpoll.js 2>&1
echo; echo "########## recent trial_claims (status + creds preview) ##########"
Q -c "SELECT id, trial_type, status, bot_ref, claimed_at::timestamp(0), left(coalesce(credentials,''),140) AS cred_preview FROM trial_claims ORDER BY id DESC LIMIT 12" 2>&1
echo; echo "########## bot API reachable? ##########"
echo "BASE=$BASE"
code=$(curl -s -m 6 -o /dev/null -w '%{http_code}' -H "X-API-Key: $KEY" "$BASE/api/products" || true); echo "GET /api/products -> $code"
echo; echo "########## what the bot returns for each recent trial ref (READ-ONLY) ##########"
for ref in $(Q -tAc "SELECT bot_ref FROM trial_claims WHERE bot_ref IS NOT NULL ORDER BY id DESC LIMIT 8" 2>/dev/null); do
  echo "=== $ref ==="
  curl -s -m 10 -H "X-API-Key: $KEY" "$BASE/api/trial-status/$ref" 2>&1; echo
done
echo "== dumpTrialpoll done =="
