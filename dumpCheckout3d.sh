#!/usr/bin/env bash
# dumpCheckout3d.sh — read-only. The POST handler HEADS (where pkr/usd/chosen/finalPkr/R are set),
# which precede the INSERTs already seen. Last read before Stage 3.
set -uo pipefail
GSZ=/opt/gsz; F="$GSZ/routes/checkout.js"
win(){ awk -v s="$1" -v e="$2" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$F"; }
echo "### single POST /checkout head (730-792) ###"; win 730 792
echo
echo "### cart POST head (855-925) ###"; win 855 925
echo "== END =="
