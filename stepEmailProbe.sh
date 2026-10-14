#!/usr/bin/env bash
# stepEmailProbe.sh — READ-ONLY. Dump lib/emails.js (delivery email) + how it's called, so I can
# restyle it premium (light) and render per-type from the bot fields.
set -u
GSZ=/opt/gsz; cd "$GSZ"
echo "########## lib/emails.js (lines: $(wc -l < lib/emails.js 2>/dev/null)) ##########"
cat -n lib/emails.js 2>/dev/null
echo ""
echo "########## callers: emailOrder / emailDelivered / deliveryEmail ##########"
grep -rnE "deliveryEmail|emailOrder\(|emailDelivered\(|require\('./emails'|require\(\"\./emails\"|emails\.deliveryEmail" routes lib 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head
