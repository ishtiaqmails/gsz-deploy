#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### order_detail route: what columns it loads into o (45-56) ###"
sed -n '45,56p' routes/adminOrders.js
echo "### ALLOW list ###"
grep -nE "ALLOW" routes/adminOrders.js | head
echo
echo "### where failure reason / fulfillment outcome is written ###"
grep -rnE "claim_result|owner_alerts|delivered_at|verified_at|'failed'|status='failed'|fulfil|reason" routes/checkout.js lib/*.js 2>/dev/null | grep -viE "\.bak|\.xbak" | head -30
echo
echo "### real data: a failed + a delivered order (detail columns) ###"
PID=$(pm2 pid gsz 2>/dev/null | head -1 | tr -dc '0-9')
[ -r "/proc/$PID/environ" ] && while IFS= read -r -d '' kv; do export "$kv" 2>/dev/null || true; done < "/proc/$PID/environ"
cat > .gszm_d.js <<'JS'
(async()=>{ try{ const fs=require('fs'); const {Pool}=require('pg'); let p; try{const s=fs.readFileSync('server.js','utf8');const m=s.match(/new\s+Pool\s*\(([\s\S]*?)\)/);p=new Pool(m&&m[1].trim()?eval('('+m[1]+')'):{});}catch(e){p=new Pool();}
  const r=await p.query("SELECT order_no,status,source,bot_order_id,bot_sku,bot_plan_key,bot_type,amount_claimed,claim_result,owner_alerts,verified_at,delivered_at,created_at,fields,bot_fields FROM orders WHERE status IN ('failed','delivered','delivering') ORDER BY (status='failed') DESC, id DESC LIMIT 4");
  r.rows.forEach(function(o){ console.log('----', o.order_no, '|', o.status, '----'); Object.keys(o).forEach(function(k){ var v=o[k]; if(v&&typeof v==='object') v=JSON.stringify(v); console.log('  '+k+': '+(v===null?'null':String(v).slice(0,300))); }); });
  await p.end(); }catch(e){ console.log('ERR',e.message);} process.exit(0); })();
JS
node .gszm_d.js; rm -f .gszm_d.js
