cd /opt/gsz
KEY=$(grep '^IPTV_INGEST_KEY=' /opt/gsz/.env | cut -d= -f2-)
echo "=== IPTV server list (name / stale) — are Trex & Mega even listed? ==="
SRV=$(curl -s --max-time 20 "http://localhost:3900/internal/iptv/servers?key=$KEY")
echo "total servers: $(printf '%s' "$SRV" | grep -oE '\"server\":' | wc -l)"
printf '%s' "$SRV" | tr '}' '\n' | grep -iE 'trex|mega' || echo "  NEITHER trex nor mega appear in the agent server list"
echo
echo "=== admin cart-order display: orders.ejs ==="
grep -nE "product_name|\.items|cart|plan_label" views/admin/orders.ejs | head -14
echo "--- order_detail.ejs ---"
grep -nE "product_name|\.items|cart|plan_label|order_no|<h1|Product" views/admin/order_detail.ejs | head -24
echo DONE
