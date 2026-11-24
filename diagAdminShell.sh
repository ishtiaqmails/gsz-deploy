#!/usr/bin/env bash
# READ-ONLY. The admin page shell/layout + auth + an example list page, to build the Customers page to match.
Z=/opt/zayron; cd "$Z"
echo "### admin layout/shell function (the page wrapper) ###"
grep -nE "function (layout|shell|page|adminPage|wrap)\b|function.*\{.*doctype|res.send\(.*</body>|const layout|= function.*html" routes/admin.js | head
echo
echo "### find the wrapper used by list pages (around /payments 1680-1700) ###"
sed -n '1685,1702p' routes/admin.js
echo
echo "### the layout function definition (search 'doctype' / head build) ###"
grep -n "doctype\|<head>\|function L(\|function page(\|const page=\|const L=\|module.exports" routes/admin.js | head
echo
echo "### admin auth middleware ###"
grep -nE "requireAdmin|router.use|session.admin|admin_logged|isAdmin|checkAuth" routes/admin.js | head
echo DONE
