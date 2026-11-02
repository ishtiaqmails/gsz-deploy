#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### review.ejs form markup (field names) ###"
grep -nE "<form|name=|action=|select|input|textarea|stars|product|button" views/review.ejs | grep -viE '\.bak' | head -40
echo
echo "### POST /review handler: exact fields read ###"
sed -n '36,52p' routes/reviewpublic.js
echo
echo "### how review.ejs gets its product list (route render locals) ###"
grep -nE "res.render\(.*review|products|prod|slug|preselect" routes/reviewpublic.js | grep -viE '\.bak' | head
