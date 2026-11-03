GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "===== A) ADMIN VIEWS ====="
ls -1 views/admin/ | tr '\n' ' '; echo
echo "-- shell top: responsive + table CSS --"
F=$(ls views/admin/_shell_top* 2>/dev/null | head -1); echo "shell file: $F"
[ -n "$F" ] && grep -nE "@media|overflow|<table|\.dtable|\.otable|\.dcard|grid-template-columns|white-space|text-overflow|min-width:[0-9]|table-layout" "$F" | head -70
echo "-- orders LIST view (table markup) --"
OV=views/admin/orders.ejs
[ -f "$OV" ] && grep -nE "<table|<thead|<tbody|<tr|<td|<th|class=\"|/admin/orders/|dtable|otable|overflow|wrap" "$OV" | head -55
echo "-- order DETAIL: route + view file --"
grep -rn "Order detail error" routes/*.js | head
grep -rn "render('admin/order" routes/*.js | head
ls -1 views/admin/ | grep -i order
echo
echo "===== B) BOT DELIVERY MESSAGE ORDER ====="
echo "-- files that build the 4 messages --"
grep -rln "Payment Confirmed\|Payment confirmed\|Order Received\|Order received\|Received Order\|Instructions\|Warranty\|Login Credentials\|credentials" lib/*.js routes/whatsapp.js | head
echo "-- deliver.js: send sequence --"
[ -f lib/deliver.js ] && grep -nE "Payment|Received|Order|Instruction|Warranty|credential|sendText|await send|msgs?\.push|\\bsend\\(|return \\[|join" lib/deliver.js | head -60
echo DONE
