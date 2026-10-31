#!/usr/bin/env bash
set -uo pipefail
GSZ=/opt/gsz
sec(){ echo; echo "========== $* =========="; }

sec "A) every hardcoded 923141892712 (file:line:context — to make dynamic)"
grep -rn "923141892712" "$GSZ/routes" "$GSZ/views" 2>/dev/null | sed 's/^\(.\{200\}\).*/\1…/' | head -50

sec "B) bot activity vocabulary (wa_audit_log events + heartbeat keys) for the live monitor"
grep -rhoE "wa_audit_log\(event[^)]*\)|event='[A-Z_]+'|'[A-Z_]{4,}'," "$GSZ/routes/whatsapp.js" 2>/dev/null | grep -oE "[A-Z_]{4,}" | sort -u | head -30
echo "--- audit log columns (from the INSERT) ---"
grep -nE "INSERT INTO wa_audit_log" "$GSZ/routes/whatsapp.js" 2>/dev/null | head -3

sec "C1) auth view files"
ls "$GSZ/views/account" 2>/dev/null | grep -iE "login|signup|register|auth|whatsapp" 
echo "--- where /login and /signup are handled + rendered ---"
grep -rnE "router\.(get|post)\('/login|router\.(get|post)\('/signup|res\.render\('account/(login|signup)" "$GSZ/routes/account.js" "$GSZ/routes/accountSecurity.js" 2>/dev/null | head

sec "C2) signup view (the phone/WhatsApp field) FULL"
for f in signup register login; do [ -f "$GSZ/views/account/$f.ejs" ] && { echo "### views/account/$f.ejs"; sed -n '1,160p' "$GSZ/views/account/$f.ejs"; }; done

sec "C3) signup + login POST handlers (how phone/wa_number is captured & stored)"
awk '/router\.(get|post)\(.(\/signup|\/login)./{p=1} p{print NR": "$0} /^  \}\);/{if(p)c++; if(c>=1 && p){p=0}}' "$GSZ/routes/account.js" 2>/dev/null | head -120
