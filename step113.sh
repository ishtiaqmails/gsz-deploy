#!/usr/bin/env bash
# ============================================================================
#  GSZ step113 — real per-plan stock + "Out of stock" on product pages (#1).
#  Feeds each plan's true availability (inventory count / bot 'stock' type) to
#  the pills, which already render "In stock · N left" / grey "Out of stock"
#  and disable Buy. Safe + idempotent; restores on failure.
# ============================================================================
set -euo pipefail
GSZ=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-step113-$TS"
TMP=$(mktemp -d)
F=routes/products.js

echo "==> step113: real per-plan stock on product pages"
mkdir -p "$BK/$(dirname "$F")"; cp "$GSZ/$F" "$BK/$F"
echo "    backup: $BK"

restore() { echo "!!  FAILED — restoring"; cp "$BK/$F" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; echo "!!  restored."; }
trap 'restore' ERR

echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTEzIHBhdGNoZXIg4oCUIGZlZWQgcmVhbCBwZXItcGxhbiBzdG9jayB0byB0aGUgcHJvZHVjdCBwYWdlIHBpbGxzLgogICBNaXJyb3JzIGNoZWNrb3V0IGF2YWlsYWJpbGl0eSAoaW52ZW50b3J5IGNvdW50IC8gYm90ICdzdG9jaycgdHlwZSkuIFRoZQogICBwcm9kdWN0LmVqcyBwaWxscyBhbHJlYWR5IHJlbmRlciBwbC5pbl9zdG9jayAvIHBsLnN0b2NrX2NvdW50LiBJZGVtcG90ZW50LiAqLwpjb25zdCBmcyA9IHJlcXVpcmUoJ2ZzJyk7CmNvbnN0IHBhdGggPSByZXF1aXJlKCdwYXRoJyk7CmNvbnN0IFJPT1QgPSBwcm9jZXNzLmFyZ3ZbMl07CmlmICghUk9PVCkgeyBjb25zb2xlLmVycm9yKCd1c2FnZTogcGF0Y2hfc3RlcDExMy5qcyA8Z3N6LXJvb3Q+Jyk7IHByb2Nlc3MuZXhpdCgxKTsgfQoKZnVuY3Rpb24gcGF0Y2gocmVsLCBlZGl0cykgewogIGNvbnN0IGZpbGUgPSBwYXRoLmpvaW4oUk9PVCwgcmVsKTsKICBsZXQgcyA9IGZzLnJlYWRGaWxlU3luYyhmaWxlLCAndXRmOCcpOwogIGZvciAoY29uc3QgZSBvZiBlZGl0cykgewogICAgaWYgKHMuaW5kZXhPZihlLmd1YXJkKSA+PSAwKSB7IGNvbnNvbGUubG9nKCdza2lwIChhbHJlYWR5KTogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7IGNvbnRpbnVlOyB9CiAgICBjb25zdCBmaXJzdCA9IHMuaW5kZXhPZihlLmZpbmQpOwogICAgaWYgKGZpcnN0IDwgMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTUlTUzogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgICBpZiAocy5pbmRleE9mKGUuZmluZCwgZmlyc3QgKyAxKSA+PSAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBOT1QgVU5JUVVFOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIHMgPSBzLnNsaWNlKDAsIGZpcnN0KSArIGUucmVwbGFjZSArIHMuc2xpY2UoZmlyc3QgKyBlLmZpbmQubGVuZ3RoKTsKICAgIGNvbnNvbGUubG9nKCdwYXRjaGVkOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICB9CiAgZnMud3JpdGVGaWxlU3luYyhmaWxlLCBzKTsKfQoKY29uc3QgU0VMX0ZJTkQgPSAiJ1NFTEVDVCBsYWJlbCwgcHJpY2VfcGtyLCBvbGRfcGtyLCBzb3VyY2UsIGJvdF9za3UsIGJvdF90eXBlIEZST00gcHJvZHVjdF9wbGFucyBXSEVSRSBwcm9kdWN0X2lkPSQxIE9SREVSIEJZIHNvcnQsIGlkJywgW3Byb3cuaWRdIjsKY29uc3QgU0VMX1JFUEwgPSAiJ1NFTEVDVCBpZCwgbGFiZWwsIHByaWNlX3Brciwgb2xkX3Brciwgc291cmNlLCBib3Rfc2t1LCBib3RfdHlwZSBGUk9NIHByb2R1Y3RfcGxhbnMgV0hFUkUgcHJvZHVjdF9pZD0kMSBPUkRFUiBCWSBzb3J0LCBpZCcsIFtwcm93LmlkXSI7Cgpjb25zdCBCVF9GSU5EID0gImNvbnN0IGJvdFR5cGVzID0ge307IGxldCBuZWVkTWFjID0gZmFsc2U7IjsKY29uc3QgQlRfUkVQTCA9ICJjb25zdCBib3RUeXBlcyA9IHt9OyBjb25zdCBib3REZWxpdmVyeSA9IHt9OyBsZXQgbmVlZE1hYyA9IGZhbHNlOyI7Cgpjb25zdCBGRV9GSU5EID0gIiAgICAgICAgICAuZm9yRWFjaChiID0+IHsgYm90VHlwZXNbYi5za3VdID0gQXJyYXkuaXNBcnJheShiLnR5cGVzKSA/IGIudHlwZXMgOiBbXTsgaWYgKFsnaG90cGxheWVyJywnaWJvc29sJywnemF5cm9uJ10uaW5jbHVkZXMoYi5kZWxpdmVyeV90eXBlKSkgbmVlZE1hYyA9IHRydWU7IH0pOyI7CmNvbnN0IEZFX1JFUEwgPSAiICAgICAgICAgIC5mb3JFYWNoKGIgPT4geyBib3RUeXBlc1tiLnNrdV0gPSBBcnJheS5pc0FycmF5KGIudHlwZXMpID8gYi50eXBlcyA6IFtdOyBib3REZWxpdmVyeVtiLnNrdV0gPSBiLmRlbGl2ZXJ5X3R5cGU7IGlmIChbJ2hvdHBsYXllcicsJ2lib3NvbCcsJ3pheXJvbiddLmluY2x1ZGVzKGIuZGVsaXZlcnlfdHlwZSkpIG5lZWRNYWMgPSB0cnVlOyB9KTsiOwoKY29uc3QgTUFQX0ZJTkQgPSAiICAgICAgY29uc3QgcGxhbnMgPSBwbGFuUm93cy5tYXAociA9PiB7IjsKY29uc3QgTUFQX1JFUEwgPQogICIgICAgICAvLyBwZXItcGxhbiByZWFsIHN0b2NrIGZvciB0aGUgcGlsbHMgKG1pcnJvcnMgY2hlY2tvdXQgYXZhaWxhYmlsaXR5KVxuIgorICIgICAgICBjb25zdCBhdmFpbCA9IHt9O1xuIgorICIgICAgICBmb3IgKGNvbnN0IHIgb2YgcGxhblJvd3MpIHtcbiIKKyAiICAgICAgICB0cnkge1xuIgorICIgICAgICAgICAgaWYgKHIuc291cmNlID09PSAnaW52ZW50b3J5Jykge1xuIgorICIgICAgICAgICAgICBjb25zdCBuID0gKGF3YWl0IHBvb2wucXVlcnkoXCJTRUxFQ1QgY291bnQoKik6OmludCBuIEZST00gaW52ZW50b3J5X2l0ZW1zIFdIRVJFIHBsYW5faWQ9JDEgQU5EIHN0YXR1cz0nYXZhaWxhYmxlJ1wiLCBbci5pZF0pKS5yb3dzWzBdLm47XG4iCisgIiAgICAgICAgICAgIGF2YWlsW3IuaWRdID0geyBpbl9zdG9jazogbiA+IDAsIHN0b2NrX2NvdW50OiBuIH07XG4iCisgIiAgICAgICAgICB9IGVsc2UgaWYgKHIuc291cmNlID09PSAnYm90JyAmJiByLmJvdF9za3UgJiYgYm90RGVsaXZlcnlbci5ib3Rfc2t1XSA9PT0gJ3N0b2NrJyAmJiBib3RhcGkuY29uZmlndXJlZCgpKSB7XG4iCisgIiAgICAgICAgICAgIGNvbnN0IHNyZXMgPSBhd2FpdCBib3RhcGkuZ2V0U3RvY2soci5ib3Rfc2t1KTtcbiIKKyAiICAgICAgICAgICAgYXZhaWxbci5pZF0gPSB7IGluX3N0b2NrOiBzcmVzLmF2YWlsYWJsZSAhPT0gZmFsc2UsIHN0b2NrX2NvdW50OiAoc3Jlcy5jb3VudCAhPSBudWxsID8gc3Jlcy5jb3VudCA6IG51bGwpIH07XG4iCisgIiAgICAgICAgICB9XG4iCisgIiAgICAgICAgfSBjYXRjaCAoZSkgeyAvKiB1bmtub3duIC0+IG5vIHN0b2NrIGJhZGdlICovIH1cbiIKKyAiICAgICAgfVxuIgorICIgICAgICBjb25zdCBwbGFucyA9IHBsYW5Sb3dzLm1hcChyID0+IHsiOwoKY29uc3QgUkVUX0ZJTkQgPSAiICAgICAgICByZXR1cm4geyBsYWJlbDogci5sYWJlbCwgcHJpY2U6IE51bWJlcihyLnByaWNlX3BrciB8fCAwKSwgb2xkOiBOdW1iZXIoci5vbGRfcGtyIHx8IDApLCB0eXBlczogdCB9OyI7CmNvbnN0IFJFVF9SRVBMID0KICAiICAgICAgICBjb25zdCBhID0gYXZhaWxbci5pZF0gfHwge307XG4iCisgIiAgICAgICAgcmV0dXJuIHsgbGFiZWw6IHIubGFiZWwsIHByaWNlOiBOdW1iZXIoci5wcmljZV9wa3IgfHwgMCksIG9sZDogTnVtYmVyKHIub2xkX3BrciB8fCAwKSwgdHlwZXM6IHQsIGluX3N0b2NrOiBhLmluX3N0b2NrLCBzdG9ja19jb3VudDogYS5zdG9ja19jb3VudCB9OyI7CgpwYXRjaCgncm91dGVzL3Byb2R1Y3RzLmpzJywgWwogIHsgbmFtZTogJ3NlbGVjdC1wbGFuLWlkJywgZ3VhcmQ6ICJTRUxFQ1QgaWQsIGxhYmVsLCBwcmljZV9wa3IsIG9sZF9wa3IsIHNvdXJjZSwgYm90X3NrdSwgYm90X3R5cGUgRlJPTSBwcm9kdWN0X3BsYW5zIiwgZmluZDogU0VMX0ZJTkQsIHJlcGxhY2U6IFNFTF9SRVBMIH0sCiAgeyBuYW1lOiAnYm90RGVsaXZlcnktZGVjbCcsIGd1YXJkOiAnY29uc3QgYm90RGVsaXZlcnkgPSB7fTsnLCBmaW5kOiBCVF9GSU5ELCByZXBsYWNlOiBCVF9SRVBMIH0sCiAgeyBuYW1lOiAnYm90RGVsaXZlcnktY2FwdHVyZScsIGd1YXJkOiAnYm90RGVsaXZlcnlbYi5za3VdID0gYi5kZWxpdmVyeV90eXBlOycsIGZpbmQ6IEZFX0ZJTkQsIHJlcGxhY2U6IEZFX1JFUEwgfSwKICB7IG5hbWU6ICdhdmFpbGFiaWxpdHktbG9vcCcsIGd1YXJkOiAncGVyLXBsYW4gcmVhbCBzdG9jayBmb3IgdGhlIHBpbGxzJywgZmluZDogTUFQX0ZJTkQsIHJlcGxhY2U6IE1BUF9SRVBMIH0sCiAgeyBuYW1lOiAncGxhbi1yZXR1cm4tc3RvY2snLCBndWFyZDogJ2luX3N0b2NrOiBhLmluX3N0b2NrLCBzdG9ja19jb3VudDogYS5zdG9ja19jb3VudCcsIGZpbmQ6IFJFVF9GSU5ELCByZXBsYWNlOiBSRVRfUkVQTCB9Cl0pOwpjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOwo=" | base64 -d > "$TMP/patch_step113.js"
echo "==> applying patch"
node "$TMP/patch_step113.js" "$GSZ"

echo "==> validating"
node --check "$GSZ/$F"

echo "==> restarting app"
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
sleep 2

echo "==> health checks"
CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true)
[ "$CODE" = "200" ] && echo "    homepage 200: OK" || { echo "    homepage $CODE"; false; }
SLUG=$(cd "$GSZ" && NODE_PATH="$GSZ/node_modules" node -e "require('dotenv/config');const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:+(process.env.DB_PORT||5432),user:process.env.DB_USER,password:process.env.DB_PASS,database:process.env.DB_NAME});p.query(\"SELECT slug FROM products WHERE active AND NOT hidden ORDER BY id LIMIT 1\").then(function(r){console.log(r.rows[0]?r.rows[0].slug:'');return p.end();}).catch(function(){console.log('')})" 2>/dev/null || true)
if [ -n "$SLUG" ]; then
  PC=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:3900/product/$SLUG" || true)
  [ "$PC" = "200" ] && echo "    product page renders ($SLUG): OK" || { echo "    product page $SLUG -> $PC"; false; }
fi

trap - ERR
rm -rf "$TMP"
echo ""
echo "==> step113 OK ✅"
echo "    • Product pages now show real stock per plan: 'In stock · N left' or a greyed 'Out of stock'."
echo "    • Out-of-stock plans disable Buy / Add to cart (checkout already blocked them too)."
echo "    • Inventory plans use live counts; bot 'stock' plans use the bot's stock; manual plans show no count."
