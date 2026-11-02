#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### order_detail.ejs: status badge + Update status card (60-135) ###"
sed -n '60,135p' views/admin/order_detail.ejs
echo
echo "### adminOrders.js: status transitions + timestamps ###"
grep -nE "UPDATE orders|status|delivered_at|paid_at|verified_at|approved_at|now\(\)|/status|statusLog|order_events" routes/adminOrders.js | grep -viE "\.bak" | head -40
echo
echo "### orders table timestamp-ish columns actually present ###"
PID=$(pm2 pid gsz 2>/dev/null | head -1 | tr -dc '0-9')
[ -r "/proc/$PID/environ" ] && while IFS= read -r -d '' kv; do export "$kv" 2>/dev/null || true; done < "/proc/$PID/environ"
cat > .gszm_d.js <<'JS'
(async()=>{ try{ const fs=require('fs'); const {Pool}=require('pg'); let p; try{const s=fs.readFileSync('server.js','utf8');const m=s.match(/new\s+Pool\s*\(([\s\S]*?)\)/);p=new Pool(m&&m[1].trim()?eval('('+m[1]+')'):{});}catch(e){p=new Pool();}
  const c=await p.query("SELECT column_name,data_type FROM information_schema.columns WHERE table_name='orders' ORDER BY ordinal_position");
  console.log(c.rows.map(function(r){return r.column_name+':'+r.data_type;}).join(', '));
  const st=await p.query("SELECT DISTINCT status FROM orders");
  console.log('statuses in use:', st.rows.map(function(r){return r.status;}).join(', '));
  await p.end(); }catch(e){ console.log('ERR',e.message);} process.exit(0); })();
JS
node .gszm_d.js; rm -f .gszm_d.js
