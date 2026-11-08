cd /opt/gsz
echo "===== lib/iptv/agent.sh (phone agent) ====="
cat -n lib/iptv/agent.sh
echo
echo "===== phone vs direct logic + how phone results arrive ====="
grep -rnE "phone|agent|residential|proxy|push|POST|/internal|/api|upload|report|needsPhone|via_phone|reach" lib/iptv/worker.js lib/iptv/credsource.js routes/iptv.js 2>/dev/null | grep -v '\.bak' | head -40
echo
echo "===== last_via / last_source per panel (who pulls what) ====="
node <<'EOF'
require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ try{ const r=await pool.query("SELECT name,last_source,last_via,to_char(updated_at,'MM-DD HH24:MI') upd FROM iptv_library ORDER BY name"); r.rows.forEach(x=>console.log((x.name||'')+'  src='+(x.last_source||'-')+'  via='+(x.last_via||'-')+'  '+x.upd)); }catch(e){ console.log('ERR '+e.message); } process.exit(0); })();
EOF
echo DONE
