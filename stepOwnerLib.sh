GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "== ownerCommand location =="
grep -n "ownerCommand\|ownsess_owner\|function owner" routes/whatsapp.js | head -20
echo
echo "== command verbs / dispatch =="
grep -nE "=== '|startsWith\('|verb|parts\[0\]|cmd ==|c0 ==|first ==|switch ?\(" routes/whatsapp.js | head -50
echo
echo "== plans/price query (reuse for library) =="
grep -nE "product_plans|bot_sku|price_usd|\.label|ORDER BY|category|iptv_library" routes/whatsapp.js | head -40
echo
echo "== help text block (owner) =="
grep -nE "help|Commands|Owner|library|menu" routes/whatsapp.js | head -30
echo
echo "== dump ownerCommand function (start +150) =="
L=$(grep -n "function ownerCommand" routes/whatsapp.js | head -1 | cut -d: -f1); [ -n "$L" ] && sed -n "${L},$((L+150))p" routes/whatsapp.js
echo DONE
