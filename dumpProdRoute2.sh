#!/usr/bin/env bash
# dumpProdRoute2 — the LIVE routes/products.js plan pieces only: the planRows SELECT and the
# plan .map() return object, so `popular` is threaded through exactly.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
f=routes/products.js
echo "########## planRows query / product_plans SELECTs (live) ##########"
grep -nE "planRows|FROM product_plans|return \{ label: r\.label|in_stock|stock_count" "$f"
echo
echo "########## context around planRows assignment ##########"
ln=$(grep -nE "planRows\s*=" "$f" | head -1 | cut -d: -f1)
if [ -n "$ln" ]; then start=$((ln-2)); [ "$start" -lt 1 ] && start=1; sed -n "${start},$((ln+10))p" "$f"; fi
echo
echo "########## context around the plan .map() return ##########"
ln2=$(grep -nE "return \{ label: r\.label" "$f" | head -1 | cut -d: -f1)
if [ -n "$ln2" ]; then start=$((ln2-6)); [ "$start" -lt 1 ] && start=1; sed -n "${start},$((ln2+2))p" "$f"; fi
echo "== dumpProdRoute2 done =="
