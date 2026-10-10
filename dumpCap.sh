#!/usr/bin/env bash
# dumpCap — retrieve/capability model (otp/link/household + limits) for Get Code eligibility.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "## bot_products.retrieve samples (capability config shape) ##"
Q -c "SELECT sku, left(name,16) AS name, retrieve FROM bot_products WHERE retrieve IS NOT NULL AND left(retrieve::text,2) NOT IN ('','nu') LIMIT 6" 2>&1 | head -30

echo "## where cap/retrieve is computed in whatsapp.js (credentials route) ##"
grep -nE "cap|retrieve|household|\.otp|\.link|enabled|limit|retrieveOtp|retrieveLink" routes/whatsapp.js 2>/dev/null | head -45

echo "## otp + link + subscription handlers (sed 150-215) ##"
sed -n '150,215p' routes/whatsapp.js
echo "== dumpCap done =="
