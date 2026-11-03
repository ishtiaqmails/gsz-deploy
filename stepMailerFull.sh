GSZ=/opt/gsz; cd $GSZ
echo "===== lib/mailer.js (full) ====="
cat -n lib/mailer.js
echo
echo "===== mailer callers (non-backup) ====="
grep -rnE "require\(['\"][^'\"]*mailer['\"]\)|mailer\.(send|configured)|\.send\(" lib routes server.js 2>/dev/null | grep -v '\.bak' | grep -iE "mailer|mail" | head
echo
echo "===== admin route mounts in server.js ====="
grep -nE "app.use\(['\"]/admin|require\(['\"]\./routes/admin" server.js
echo
echo "===== sidebar nav block in _shell_top.ejs (admin links) ====="
grep -nE "href=\"/admin/|nav-sec|navSection|>OVERVIEW<|>CATALOG<|>SALES<|>FULFIL|nav-lbl|mbar" views/admin/_shell_top.ejs | head -60
echo DONE
