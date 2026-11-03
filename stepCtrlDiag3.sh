GSZ=/opt/gsz; cd $GSZ
echo "== adminIptv route signatures + classify calls =="
grep -n "router\.\(get\|post\)\|classify(\|module.exports\|function(\|=>" routes/adminIptv.js | grep -n "router\.\|classify(\|module.exports" | head -40
echo "== top of adminIptv (requires, pool, auth, exports) =="
sed -n '1,14p' routes/adminIptv.js
echo "== one POST route body for pattern =="
L=$(grep -n "router.post('/iptv-library" routes/adminIptv.js | head -1 | cut -d: -f1); [ -n "$L" ] && sed -n "${L},$((L+22))p" routes/adminIptv.js
echo "== GET /iptv-library render (classify usage + res.render) =="
L=$(grep -n "router.get('/iptv-library'" routes/adminIptv.js | head -1 | cut -d: -f1); [ -n "$L" ] && sed -n "${L},$((L+45))p" routes/adminIptv.js
echo "== iptv.ejs anchors =="
grep -n "Phone Agent\|Add any\|addSource\|dpanel\|lib-add\|<form\|<script\|refreshLog\|resync\|data-base\|function " views/admin/iptv.ejs | head -60
echo DONE
