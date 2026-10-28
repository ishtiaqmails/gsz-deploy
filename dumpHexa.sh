#!/usr/bin/env bash
# dumpHexa.sh — read-only. Why Hexa4K shows versions + why its trial is hidden.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "### A) Hexa4K as the BOT reports it (types + trial) ###"
node - "$GSZ" <<'NODE' 2>&1 | head -20
const R=process.argv[2]; try{require(R+'/node_modules/dotenv').config({path:R+'/.env'});}catch(e){}
const botapi=require(R+'/lib/botapi');
(async()=>{
  const list=await botapi.getProducts(true);
  const p=(list||[]).find(x=>String(x.sku||'')==='155'||String(x.id||'')==='155'||/hexa/i.test(x.name||''));
  if(!p){console.log('  Hexa4K not in bot list'); return;}
  console.log('  name='+p.name+' | sku='+p.sku+' | id='+p.id+' | delivery_type='+p.delivery_type);
  console.log('  types='+JSON.stringify(p.types||[]));
  console.log('  trial='+JSON.stringify(p.trial||null));
})().catch(e=>console.log('  bot err:',e.message));
NODE

echo
echo "### B) website DB: Hexa4K plan + bot_products.types + trial_servers ###"
node - "$GSZ" <<'NODE' 2>&1 | head -40
const R=process.argv[2];
try{require(R+'/node_modules/dotenv').config({path:R+'/.env'});}catch(e){}
const {Pool}=require(R+'/node_modules/pg');
const E=process.env;
let pool;
try {
  if (E.DATABASE_URL) pool=new Pool({connectionString:E.DATABASE_URL});
  else if (E.DB_HOST||E.DB_NAME||E.DB_USER) pool=new Pool({host:E.DB_HOST||'127.0.0.1',port:+(E.DB_PORT||5432),user:E.DB_USER||E.PGUSER,password:(E.DB_PASS||E.DB_PASSWORD||E.PGPASSWORD||'')+'',database:E.DB_NAME||E.PGDATABASE});
  else pool=new Pool();
} catch(e){ console.log('  pool-init:',e.message); }
(async()=>{
  try {
    const bp=await pool.query("SELECT sku,LEFT(name,24) nm,types,COALESCE(is_active,true) a,COALESCE(missing,false) m FROM bot_products WHERE sku='155' OR name ILIKE '%hexa%'");
    bp.rows.forEach(r=>console.log('  bot_products: sku='+r.sku+' '+r.nm+' active='+r.a+' missing='+r.m+' types='+JSON.stringify(r.types)));
    const pl=await pool.query("SELECT pr.name prod, pp.label, pp.source, pp.bot_sku, pp.bot_type, pp.version_labels FROM product_plans pp JOIN products pr ON pr.id=pp.product_id WHERE pp.bot_sku='155' OR pr.name ILIKE '%hexa%'");
    if(!pl.rows.length) console.log('  product_plans: (no mapped plan found for Hexa4K)');
    pl.rows.forEach(r=>console.log('  plan: '+r.prod+' | '+r.label+' | source='+r.source+' bot_sku='+r.bot_sku+' bot_type='+(r.bot_type||'-')+' version_labels='+JSON.stringify(r.version_labels)));
    const ts=await pool.query("SELECT sku,name,enabled,duration_label,duration_hours,max_per_customer FROM trial_servers WHERE sku='155' OR name ILIKE '%hexa%'");
    if(!ts.rows.length) console.log('  trial_servers: (no row for Hexa4K — trial was never saved server-side)');
    ts.rows.forEach(r=>console.log('  trial_servers: sku='+r.sku+' enabled='+r.enabled+' label='+(r.duration_label||'-')+' hrs='+(r.duration_hours||'-')+' max='+(r.max_per_customer||'-')));
  } catch(e){ console.log('  db err:',e.message); }
  try{await pool.end();}catch(e){}
})();
NODE
echo "== END =="
