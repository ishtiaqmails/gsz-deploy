#!/usr/bin/env bash
# diagGszAdminWaView — the admin WhatsApp view's verify-policy toggle markup, to add a matching wa_verify_mode
# switch beside it. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ views/admin/whatsapp.ejs — verify-policy / toggle section ############"
grep -n "verify-policy\|require\|requireVerify\|toggle\|switch\|<form\|verify your whatsapp\|policy\|checkbox" views/admin/whatsapp.ejs 2>/dev/null | head -30
echo
echo "--- the verify-policy form block (with surrounding context) ---"
L=$(grep -n "verify-policy" views/admin/whatsapp.ejs 2>/dev/null | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L>20?L-20:1)),$((L+25))p" views/admin/whatsapp.ejs || echo "(verify-policy not found; dumping first 60 lines)"
[ -z "$L" ] && sed -n '1,60p' views/admin/whatsapp.ejs
echo DONE
