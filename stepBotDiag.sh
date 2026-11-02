#!/usr/bin/env bash
# stepBotDiag.sh — READ ONLY. Inspect gszwabot forwarding + site webhook + owner + product/plan/inventory schema.
set -uo pipefail
GSZ=/opt/gsz; WB=/opt/gsz-wabot

echo "===== A) SITE webhook handler (/internal/whatsapp/incoming) ====="
RF=$(grep -rln "whatsapp/incoming" "$GSZ/routes" "$GSZ"/*.js 2>/dev/null | grep -v node_modules | head -1)
echo "file: ${RF:-<none>}"
if [ -n "${RF:-}" ]; then
  L=$(grep -n "whatsapp/incoming" "$RF" | head -1 | cut -d: -f1)
  echo "---- handler from line $L (90 lines) ----"
  sed -n "${L},$((L+90))p" "$RF"
fi

echo; echo "===== B) WABOT /opt/gsz-wabot — files + how incoming is forwarded ====="
ls -1 "$WB" 2>/dev/null | grep -v node_modules | head -25
MF=$(grep -rln -E "messages.upsert|whatsapp/incoming|internal" "$WB" --include=*.js 2>/dev/null | grep -v node_modules | head -1)
echo "main msg file: ${MF:-<none>}"
if [ -n "${MF:-}" ]; then
  echo "---- forward/filter logic (grep) ----"
  grep -nE "messages.upsert|incoming|internal|owner|OWNER|conversation|fromMe|return" "$MF" 2>/dev/null | head -30
fi

echo; echo "===== C) owner number(s) config ====="
grep -rniE "wa_owner_numbers|owner_number|OWNER_NUM|ownerNumbers|isOwner" "$GSZ/lib" "$GSZ/routes" --include=*.js 2>/dev/null | grep -v node_modules | head -15

echo; echo "===== D) DB schema (live) ====="
grep -iE 'DATABASE_URL|PGHOST|PGUSER|PGDATABASE|PGPASSWORD' "$GSZ/.env" 2>/dev/null | sed 's/=.*/=<set>/'
DBURL=$(grep -E '^DATABASE_URL=' "$GSZ/.env" 2>/dev/null | cut -d= -f2- | tr -d '"')
if [ -n "${DBURL:-}" ]; then
  for t in products product_plans; do echo "---- $t ----"; psql "$DBURL" -c "\\d $t" 2>&1 | sed -n '1,40p'; done
  echo "---- inventory-ish tables ----"; psql "$DBURL" -c "\\dt" 2>&1 | grep -iE 'invent|stock|account|nf_|unit' | head -20
else
  echo "no DATABASE_URL — env keys above show what IS set; will use those next round"
fi
echo "DONE DIAG"
