GSZ=/opt/gsz; cd $GSZ
echo "===== worker startWorker + tick interval (wanotify.js 85-101) ====="
sed -n '85,101p' lib/wanotify.js
echo
echo "===== recent wa_notifications (last order's messages) ====="
node <<'EOF'
require('dotenv').config({path:'/opt/gsz/.env'});
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
 try{
  const r=await pool.query("SELECT id, order_id, template_key, status, to_char(queued_at,'HH24:MI:SS.MS') q, to_char(next_attempt_at,'HH24:MI:SS.MS') na FROM wa_notifications ORDER BY id DESC LIMIT 16");
  r.rows.reverse().forEach(x=>console.log([x.id,'ord#'+(x.order_id||'-'),x.template_key,x.status,'q='+x.q,'na='+x.na].join('  |  ')));
 }catch(e){ console.log('ERR '+e.message); }
 process.exit(0);
})();
EOF
echo DONE
