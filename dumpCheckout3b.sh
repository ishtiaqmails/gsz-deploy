#!/usr/bin/env bash
# dumpCheckout3b.sh — read-only. The LIVE checkout.js money math + order insert, and the real
# orders schema. Robust DB connect (parse .env in node, pg from app's node_modules).
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
F="$GSZ/routes/checkout.js"

echo "### A) checkout.js size ###"; wc -l "$F"

echo
echo "### B) amount math — any hardcoded rate / usd / pkr / price_usd / live rate ###"
grep -nE "0\.0036|_usd|usd|pkr|price_usd|price_pkr|rate|amount|fmtPkr|fmt\(|Number\(req" "$F" | head -45

echo
echo "### C) payment-method building (bot accts + currency branch) ###"
grep -nE "accts|payment_methods|currency|methods\.push|isUsd|a\.key|a\.label|pricing|gsz_pricing|resolve\(" "$F" | head -30

echo
echo "### D) order INSERT + which columns are written ###"
grep -nE "INSERT INTO orders|amount_display|amount_pkr|amount_usd|currency|order_no|VALUES" "$F" | head -25

echo
echo "### E) GET/POST route signatures + render ###"
grep -nE "router\.(get|post)\(|res\.render\(|res\.redirect\(|req\.(query|body)\." "$F" | head -30

echo
echo "### F) orders schema (real columns) ###"
node -e '
const fs=require("fs"),path="/opt/gsz/.env";
let env={}; try{fs.readFileSync(path,"utf8").split(/\r?\n/).forEach(l=>{const i=l.indexOf("=");if(i>0&&!l.trim().startsWith("#")){env[l.slice(0,i).trim()]=l.slice(i+1).trim().replace(/^["\x27]|["\x27]$/g,"");}});}catch(e){}
const {Pool}=require("/opt/gsz/node_modules/pg");
const E=Object.assign({},process.env,env);
const pool=E.DATABASE_URL?new Pool({connectionString:E.DATABASE_URL}):new Pool({host:E.DB_HOST||E.PGHOST,port:E.DB_PORT||E.PGPORT||5432,user:E.DB_USER||E.PGUSER,password:E.DB_PASSWORD||E.PGPASSWORD,database:E.DB_NAME||E.PGDATABASE});
(async()=>{try{
  const r=await pool.query("select column_name,data_type from information_schema.columns where table_name=$1 order by ordinal_position",["orders"]);
  console.log("orders columns:\n"+r.rows.map(x=>"  "+x.column_name+" : "+x.data_type).join("\n"));
  const p=await pool.query("select column_name from information_schema.columns where table_name=$1 and column_name in (\x27price_pkr\x27,\x27price_usd\x27)",["product_plans"]);
  console.log("product_plans has:",p.rows.map(x=>x.column_name).join(", ")||"(none)");
}catch(e){console.log("ERR",e.message);}process.exit(0);})();
'
echo "== END =="
