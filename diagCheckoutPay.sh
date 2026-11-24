#!/usr/bin/env bash
# READ-ONLY. Checkout amount (the +1-3 rupee), payment method render, proof/screenshot, + galaxyzayron buffer.
Z=/opt/zayron; cd "$Z"
echo "### checkout amount / unique-amount / usd conversion ###"
grep -nE "price_amount|usdRate|usd|cents|unique|\\+ [0-9]|rupee|buffer|Math.round|toFixed|amount|pkr" routes/checkout.js | head -30
echo
echo "### payment methods render (SEND PAYMENT TO / YOUR PAYMENT DETAILS / proof / screenshot) ###"
grep -nE "SEND PAYMENT|YOUR PAYMENT|Binance name|screenshot|proof|upload|account|title|iban|instructions|method|m.id|payMatch|I've sent" routes/checkout.js | head -30
echo
echo "### galaxyzayron buffer system (gsz_pricing) ###"
grep -nE "buffer|usd|usdt|margin|round|binance|rate|convert" /opt/gsz/lib/gsz_pricing.js 2>/dev/null | head -20
echo DONE
