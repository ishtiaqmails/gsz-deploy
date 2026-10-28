#!/usr/bin/env bash
# dumpBotSync2.sh — read-only. The sync logic, its trigger, and live bot_products state.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "###### A) lib/botsync.js (full) ######"
cat -n "$GSZ/lib/botsync.js"

echo
echo "###### B) what calls botsync (trigger: route / cron / startup) ######"
grep -rnE "botsync|botSync|runSync|syncNow" "$GSZ"/server.js "$GSZ"/routes "$GSZ"/lib 2>/dev/null | grep -v node_modules | grep -v "lib/botsync.js" | head -20

echo
echo "###### C) how server.js builds the pg pool (to read DB the same way) ######"
grep -nE "new Pool|Pool\(|connectionString|DATABASE_URL|PGHOST|PGUSER|require\('\./lib/db'|require\('\./db'|pool *=" "$GSZ/server.js" 2>/dev/null | head -12

echo
echo "###### D) live bot_products via the app's own pg config ######"
node - "$GSZ" <<'NODE' 2>&1 | head -25
const R=process.argv[2];
require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const {Pool}=require(R+'/node_modules/pg');
// Try connection string first, then default env (PG*), then common unix-socket role.
const cs=process.env.DATABASE_URL||process.env.PG_URL||process.env.DB_URL||process.env.POSTGRES_URL;
let pool;
try { pool = cs ? new Pool({connectionString:cs}) : new Pool(); } catch(e){ console.log('pool-init-err',e.message); process.exit(0); }
(async()=>{
  try {
    const c=await pool.query("SELECT count(*)::int n FROM bot_products");
    console.log('total bot_products: '+c.rows[0].n);
    const r=await pool.query("SELECT sku,LEFT(COALESCE(name,''),30) nm,COALESCE(is_active,true) a,COALESCE(missing,false) m,updated_at FROM bot_products ORDER BY updated_at DESC NULLS LAST, sku LIMIT 15");
    r.rows.forEach(x=>console.log('  '+x.sku+' | '+x.nm+' | active='+x.a+' missing='+x.m+' | '+(x.updated_at?new Date(x.updated_at).toISOString().slice(0,16):'(no ts)')));
  } catch(e){ console.log('db-query-err:',e.message); }
  try{ await pool.end(); }catch(e){}
})();
NODE
echo "== END =="
