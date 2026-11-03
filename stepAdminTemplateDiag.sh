GSZ=/opt/gsz; cd $GSZ
echo "===== routes/adminLabels.js (first 70 lines - template) ====="
sed -n '1,70p' routes/adminLabels.js
echo
echo "===== admin auth guard (how /admin is protected) ====="
grep -nE "requireAdmin|ensureAdmin|adminAuth|req.session|redirect\('/admin/login|isAdmin|use\(" server.js | grep -iE "admin|auth|session" | head
echo
echo "===== render locals: how 'on'/active nav is passed (sample routes) ====="
grep -rnE "res.render\('admin/|on:|active:|navActive|activeNav" routes/adminLabels.js routes/adminMaintenance.js 2>/dev/null | head
echo
echo "===== define of on() in shell ====="
grep -nE "on\s*=|function on|typeof on|locals.on" views/admin/_shell_top.ejs | head
echo DONE
