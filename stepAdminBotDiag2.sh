GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "===== ORDER DETAIL VIEW (overflow suspects) ====="
grep -nE "<table|<pre|<code|grid-template|white-space|overflow|credentials|flex|width:|<div class=|wrap|rsp|data-label" views/admin/order_detail.ejs | head -80
echo
echo "===== deliveryMsg.js (message builder, 1-130) ====="
sed -n '1,130p' lib/deliveryMsg.js
echo
echo "===== where Payment Confirmed / Order Received come from ====="
grep -rln "Payment Confirmed\|Payment confirmed\|Order Received\|Order received\|received your order\|We.ve received\|payment.*confirmed" lib/*.js routes/*.js | grep -v node_modules | head
grep -rnE "Payment Confirmed|Order Received|received your order|payment received|confirmed" routes/whatsapp.js lib/deliver.js lib/wanotify.js lib/watpl.js | head -30
echo
echo "===== wanotify queue ordering (FIFO?) ====="
grep -nE "ORDER BY|enqueue|template_key|SELECT|LIMIT|process|send|pending" lib/wanotify.js | head -40
echo DONE
