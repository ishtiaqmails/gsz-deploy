#!/usr/bin/env bash
# dumpCheckout3c.sh — read-only. Exact bodies Stage 3 will edit: the amount/quote/payMethods
# block, the GET+POST /checkout handlers, both order INSERTs (VALUES + params), and the
# pay-methods AJAX endpoint. One-time read of a money-critical file.
set -uo pipefail
GSZ=/opt/gsz; F="$GSZ/routes/checkout.js"
win(){ awk -v s="$1" -v e="$2" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$F"; }

echo "### 1) money helpers: REGIONS, fmt, quote, usdtAmount, payMethods (25-115) ###"
win 25 115
echo
echo "### 2) cart/plan line build (155-200) ###"
win 155 200
echo
echo "### 3) pay-methods AJAX + coupon (620-672) ###"
win 620 672
echo
echo "### 4) GET /checkout (672-730) ###"
win 672 730
echo
echo "### 5) POST /checkout + INSERT #1 (790-850) ###"
win 790 850
echo
echo "### 6) INSERT #2 context (925-960) ###"
win 925 960
echo "== END =="
