cd /opt/gsz
echo "=== IPTV internal key var in .env ==="
KEY=$(grep -iE '^IPTV_INTERNAL_KEY=|^IPTV_KEY=|^IPTV_AGENT_KEY=|^IPTV_PULL_KEY=|^INTERNAL_IPTV_KEY=' /opt/gsz/.env | head -1 | cut -d= -f2- | tr -d '"'\'' ')
[ -n "$KEY" ] && echo "key: found" || { echo "key: NOT FOUND - showing candidate var names:"; grep -iE 'IPTV|INTERNAL' /opt/gsz/.env | sed -E 's/=.*/=<hidden>/'; }
echo
echo "=== can the engine resolve a working line for Trex & Mega? ==="
SRV=$(curl -s --max-time 20 "http://localhost:3900/internal/iptv/servers?key=$KEY")
for S in trex mega; do
  SKU=$(printf '%s' "$SRV" | tr '}' '\n' | grep -i "$S" | grep -oE '"sku":"[^"]*"' | head -1 | cut -d'"' -f4)
  echo "[$S] sku=${SKU:-<not in servers list>}"
  if [ -n "$SKU" ]; then
    R=$(curl -s --max-time 40 "http://localhost:3900/internal/iptv/url/$SKU?key=$KEY")
    echo "  resolve: $(printf '%s' "$R" | head -c 300)"
  fi
done
echo
echo "=== Order GSZ-2022: which products? ==="
node <<'EOF'
require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ try{
  const r=await pool.query("SELECT order_no,product_name,plan_label,source,status,amount_pkr,fields FROM orders WHERE order_no='GSZ-2022'");
  if(!r.rows.length){ console.log('(no order GSZ-2022)'); } else { const o=r.rows[0];
    console.log('product_name:',JSON.stringify(o.product_name),'| plan:',o.plan_label,'| source:',o.source,'| status:',o.status,'| amount:',o.amount_pkr);
    let f=o.fields; if(typeof f==='string'){ try{f=JSON.parse(f);}catch(e){} }
    console.log('fields keys:', f?Object.keys(f).join(','):'(none)');
    console.log('fields.items:', JSON.stringify((f&&f.items)||null));
  }
}catch(e){ console.log('ERR '+e.message); } process.exit(0); })();
EOF
echo DONE
