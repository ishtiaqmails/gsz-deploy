#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### product.ejs top rating area (100-120) ###"
sed -n '100,120p' views/product.ejs
echo
echo "### footer partial(s) that hold Track an order / FAQ links ###"
grep -rlnE "Track an order|FAQ & policies|Renew IPTV" views/ 2>/dev/null | grep -viE '\.bak|\.xbak'
echo
echo "### footer links block with context ###"
grep -rnE "Track an order|Renew IPTV|FAQ|footer" views/partials/*.ejs 2>/dev/null | grep -viE '\.bak|\.xbak' | head -20
