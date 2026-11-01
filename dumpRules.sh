#!/usr/bin/env bash
# dumpRules.sh — READ ONLY. How many product rules exist + show them with product & location names.
set -uo pipefail
cd /opt/gsz
node <<'NODE'
const path=require('path');
try{require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});}catch(e){}
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const n=(await pool.query('SELECT count(*)::int c FROM geo_product_rules')).rows[0].c;
  console.log('geo_product_rules total rows: '+n);
  if(n){
    const r=await pool.query(`SELECT g.id, p.name AS product, l.name AS location, l.type, g.availability, g.featured, g.recommended, g.regional_price, g.currency_override, g.special_notice, g.enabled
      FROM geo_product_rules g LEFT JOIN products p ON p.id=g.product_id LEFT JOIN geo_locations l ON l.id=g.location_id ORDER BY g.id DESC LIMIT 20`);
    console.log(JSON.stringify(r.rows,null,1));
  } else {
    console.log('(no rules saved yet — the grid Save did not write anything)');
  }
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
NODE
