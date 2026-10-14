#!/usr/bin/env bash
# stepAcctViewProbe.sh — READ-ONLY. Find the on-site order / credentials view + route, and how it
# renders delivered_credentials today, so I can restyle it premium (light) from the same data.
set -u
GSZ=/opt/gsz; cd "$GSZ"

echo "=== routes that render an order / credentials page ==="
grep -rnE "order/:|/credentials|res\.render\((['\"][^'\"]*order|['\"][^'\"]*credential)" routes/account.js 2>/dev/null | head -20

echo ""
echo "=== how delivered_credentials is shown on-site ==="
grep -rnE "delivered_credentials|credentials|res\.render" routes/account.js 2>/dev/null | grep -iE "credential|render|order_view|order_detail" | head -20

echo ""
echo "=== account views present ==="
ls -1 views/store/account 2>/dev/null | head -40
ls -1 views/account 2>/dev/null | head -40

echo ""
echo "=== which view renders credentials (search templates) ==="
grep -rlnE "delivered_credentials|Your (login|order)|credential" views 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head
