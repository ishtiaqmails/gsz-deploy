#!/usr/bin/env bash
# stepBotMsgProbe.sh — READ-ONLY. Dump the checkout.js delivery/notify + bot-submit section,
# so I can (a) close the premium-var gap on the website auto-delivery and (b) see whether GSZ
# also messages the customer for bot orders (vs the reseller bot doing it directly).
set -u
GSZ=/opt/gsz; cd "$GSZ"
echo "=== routes/checkout.js — notify/deliver/bot-submit (lines 185-335) ==="
sed -n '185,335p' routes/checkout.js
