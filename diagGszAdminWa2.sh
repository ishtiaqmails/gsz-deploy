#!/usr/bin/env bash
# diagGszAdminWa2 — the admin WhatsApp panel render (to add the wa_verify_mode toggle) + the account dashboard
# WhatsApp-verify UI + the account GET render. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ routes/adminWhatsapp.js (full) ############"
nl -ba routes/adminWhatsapp.js | head -140
echo
echo "############ account dashboard: any WhatsApp / verify UI ############"
grep -niE "whatsapp|verify|wa_verified|wa\.verified|unverified|verified|message us" views/account/dashboard.ejs 2>/dev/null | head -30
echo
echo "############ account.js GET /account render (passes wa to dashboard) ############"
grep -n "router.get('/account'," routes/account.js
L=$(grep -n "router.get('/account'," routes/account.js | head -1 | cut -d: -f1); [ -n "$L" ] && sed -n "${L},$((L+40))p" routes/account.js
echo DONE
