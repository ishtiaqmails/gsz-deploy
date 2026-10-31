#!/usr/bin/env bash
# dumpIncoming.sh — read-only. The website's /internal/whatsapp/incoming handler (where the bot
# forwards messages and gets its reply) + how the owner's number is identified. To add `price`.
set -uo pipefail
GSZ=/opt/gsz
F="$GSZ/routes/whatsapp.js"
echo "### whatsapp.js size ###"; wc -l "$F"

L=$(grep -n "/internal/whatsapp/incoming" "$F" 2>/dev/null | head -1 | cut -d: -f1 || true)
echo "### incoming handler starts near line: ${L:-<not found>} ###"
if [ -n "${L:-}" ]; then
  awk -v s=$((L-3)) -v e=$((L+90)) 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$F"
fi

echo
echo "### how the sender/identity is resolved + any 'reply'/'action' shape ###"
grep -nE "reply|action|REDIRECT|phone|pnJid|lid|identity|verified|match" "$F" 2>/dev/null | head -25

echo
echo "### owner number — where is it stored/identified? (settings keys + reset flow) ###"
grep -rnE "owner|sales_number|wa_owner|owner_number|OWNER|owner_wa|admin_wa" "$GSZ/routes/whatsapp.js" "$GSZ/routes/adminReset.js" "$GSZ/lib"/*.js "$GSZ/routes/adminWhatsapp.js" 2>/dev/null | grep -iE "owner|sales_number|admin_wa" | grep -v node_modules | head -20
echo "--- wa_settings keys that look like a number/owner (sample) ---"
grep -rnoE "wa_settings WHERE key='[a-z_]+'|key='[a-z_]*(owner|sales|number|wa)[a-z_]*'" "$GSZ/routes"/*.js "$GSZ/lib"/*.js 2>/dev/null | grep -v node_modules | sort -u | head -20
echo "== END =="
