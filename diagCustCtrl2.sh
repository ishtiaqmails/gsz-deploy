#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### account.js hashPw + verifyPw (12-50) ###"
sed -n '12,50p' routes/account.js
echo
echo "### customers.ejs view-modal shell (149-175) ###"
sed -n '149,175p' views/admin/customers.ejs
echo
echo "### customers.ejs modal JS render (215-250) ###"
sed -n '215,250p' views/admin/customers.ejs
