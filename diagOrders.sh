#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### admin order view files ###"
ls -1 views/admin 2>/dev/null | grep -iE "order"
echo
echo "### payment screenshot/receipt <img> in admin order views ###"
grep -rnE "receipt|screenshot|proof|slip|payment.?img|<img" views/admin 2>/dev/null | grep -iE "receipt|screenshot|proof|slip|payment|<img" | grep -viE "\.bak|\.xbak" | head -30
echo
echo "### where the receipt file column is referenced (route + db field) ###"
grep -rnE "receipt|screenshot|proof|slip" routes/adminOrders.js routes/checkout.js 2>/dev/null | grep -viE "\.bak" | head -20
