#!/usr/bin/env bash
# READ ONLY — app.js (full) + app.css mobile/drawer sections, for the #6 mobile audit.
APP=/opt/gsz
echo "========== BEGIN app.js (full) =========="
cat "$APP/public/js/app.js" 2>/dev/null
echo "========== END app.js =========="
echo
echo "========== app.css — @media / drawer / scroll rules (with line numbers) =========="
grep -nE '@media|\.drawer|\.scrim|\.burger|overflow|position:(fixed|sticky)|^body|^html|\.hd-tools|\.hd-search|\.nav\b' "$APP/public/css/app.css" 2>/dev/null
echo
echo "========== app.css — everything from line 300 to end (mobile rules live here) =========="
sed -n '300,2000p' "$APP/public/css/app.css" 2>/dev/null
echo "== DONE =="
