cd /opt/gsz
echo "=== IPTV proxy configured? (value hidden) ==="
grep -E "IPTV_PROXY|ALL_PROXY|^HTTP_PROXY|HTTPS_PROXY" /opt/gsz/.env 2>/dev/null | sed -E 's/=.*/=<set>/'
echo "(nothing above = no residential proxy configured in .env)"
echo
echo "=== recent pull attempts for Trex & Mega (from log) ==="
node <<'EOF'
require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ try{
  const r=await pool.query("SELECT to_char(created_at,'MM-DD HH24:MI') t, server_key, source, COALESCE(via,'-') via, status, COALESCE(note,'') note FROM iptv_library_log WHERE server_key ILIKE '%trex%' OR server_key ILIKE '%mega%' ORDER BY created_at DESC LIMIT 16");
  if(!r.rows.length) console.log('(no log rows)');
  r.rows.forEach(x=>console.log(x.t+'  '+x.server_key+'  src='+x.source+' via='+x.via+'  '+x.status+'  '+x.note));
}catch(e){ console.log('ERR '+e.message); } process.exit(0); })();
EOF
echo "=== last good vs now ==="
grep -c "." /dev/null
echo DONE
