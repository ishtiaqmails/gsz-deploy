#!/usr/bin/env bash
# stepOrdersEndpointProbe.sh — READ-ONLY. Two things:
#  (1) where a BOT order's result (delivered_credentials) is stored — to also store `fields` there
#  (2) the /account/tools/orders endpoint route + how it maps each order (to add `fields`)
set -u
GSZ=/opt/gsz; cd "$GSZ"

echo "=== (1) checkout.js: bot delivery result storage (pollOnce / delivering->delivered) ==="
grep -nE "pollOnce|orderStatus|delivered_credentials|status='delivered'|\.fields|bot_order_id" routes/checkout.js | head -30

echo ""
echo "=== (2) the live route serving /account/tools/orders ==="
F=$(grep -rlE "tools/orders" routes/*.js 2>/dev/null | grep -v '\.bak' | head -1)
echo "ROUTE FILE: ${F:-NOT FOUND}"
[ -n "${F:-}" ] && grep -nE "tools/orders|delivered_credentials|credentials:|delivery_instructions|warranty|product_note|orders.map|rows.map|res.json" "$F" | head -25

echo ""
echo "=== orders.bot_fields column exists? ==="
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ const c=(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='orders' AND column_name IN ('bot_fields','fields','bot_order_id')\")).rows.map(x=>x.column_name); console.log('orders has:', c.join(', ')||'(none of bot_fields/fields/bot_order_id)'); await p.end(); })().catch(e=>{console.error(e.message);process.exit(1);});
"
