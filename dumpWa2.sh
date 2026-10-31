#!/usr/bin/env bash
set -uo pipefail
GSZ=/opt/gsz
sec(){ echo; echo "========== $* =========="; }

sec "A) how site settings (incl wa_number) are WRITTEN — the settings table + save route"
grep -rnE "INSERT INTO settings|UPDATE settings|settings\(key|SET value.*key|loadSettings" "$GSZ/lib/storefront.js" "$GSZ/routes/admin.js" "$GSZ/routes/adminCatalog.js" 2>/dev/null | head -20
echo "--- loadSettings definition ---"
grep -nA6 "function loadSettings" "$GSZ/lib/storefront.js" 2>/dev/null

sec "B) trials flow — the gate (/api/trials + /trials/claim), where waOk is decided"
grep -nE "router\.(get|post)|waOk|wa_verified|verified|wa_number|require|whatsapp|settings|loggedIn" "$GSZ/routes/trials.js" 2>/dev/null | head -40

sec "C) current admin/wabot.ejs — size only (I will rebuild it as the control center)"
wc -l "$GSZ/views/admin/wabot.ejs" 2>/dev/null

sec "D) any HARDCODED numbers in customer-facing/verification code (to confirm change-propagates)"
grep -rhoE "92[0-9]{9,10}|447[0-9]{8,9}" "$GSZ/routes" "$GSZ/views/partials" 2>/dev/null | sort | uniq -c | sort -rn | head -15
