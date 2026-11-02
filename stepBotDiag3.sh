#!/usr/bin/env bash
# stepBotDiag3.sh — READ ONLY. How the website consumes/marks an inventory_items unit (to mirror in owner 'sell').
set -uo pipefail
GSZ=/opt/gsz

echo "===== 1) every inventory_items query (UPDATE/SELECT/INSERT) ====="
grep -rn "inventory_items" "$GSZ/routes" "$GSZ/lib" --include=*.js 2>/dev/null | grep -v node_modules | head -40

echo; echo "===== 2) consumption context — the UPDATE that marks a unit used/sold ====="
CF=$(grep -rln "inventory_items" "$GSZ/lib/deliver.js" "$GSZ/routes/checkout.js" 2>/dev/null | head -1)
echo "likely file: ${CF:-<none>}"
grep -rn -iE "UPDATE inventory_items|status='|SKIP LOCKED|FOR UPDATE|sold|consumed|assigned|used|order_no|order_id" "$GSZ/lib/deliver.js" 2>/dev/null | head -20
echo "---- deliver.js inventory block (context) ----"
if [ -f "$GSZ/lib/deliver.js" ]; then L=$(grep -n "inventory_items" "$GSZ/lib/deliver.js" | head -1 | cut -d: -f1); [ -n "${L:-}" ] && sed -n "$((L>6?L-6:1)),$((L+30))p" "$GSZ/lib/deliver.js"; fi

echo; echo "===== 3) inventory_items columns (CREATE TABLE) ====="
grep -rn -A18 "CREATE TABLE[^;]*inventory_items" "$GSZ" --include=*.js 2>/dev/null | grep -v node_modules | head -24

echo; echo "===== 4) status values used on inventory_items ====="
grep -rhoE "status\s*=\s*'[a-z_]+'" "$GSZ/lib/deliver.js" "$GSZ/routes/checkout.js" "$GSZ/routes/adminInventory.js" 2>/dev/null | sort | uniq -c | sort -rn | head -15
echo DONE3
