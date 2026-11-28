#!/usr/bin/env bash
# diagWabotAudit4 — READ-ONLY. Finds the data source for warranty + instructions (so the premium owner
# delivery can fill them), and shows the schema + a sample own-stock plan. Changes nothing.
set +e
G=/opt/gsz; cd "$G"
echo "########## A. Where customer credentials/instructions templates are composed ##########"
grep -rn "whatsapp.credentials\|whatsapp.instructions\|instructions_section\|warranty_section\|warranty_days" routes lib 2>/dev/null | grep -v node_modules | grep -vE '\.retired|\.bak' | head -40

echo
echo "########## B. bot_products columns (retrieve/delivery_note/warranty) ##########"
node -e '
const {Pool}=require("pg");require("dotenv").config();
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{try{
 for(const tbl of ["products","product_plans","bot_products"]){
   const r=(await p.query("SELECT column_name,data_type FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position",[tbl])).rows;
   console.log("-- "+tbl+": "+r.map(x=>x.column_name).join(", "));
 }
}catch(e){console.log("ERR",e.message);} await p.end();})();' 2>&1 | head -20

echo
echo "########## C. Sample own-stock (inventory) plans: do they carry bot_sku / warranty / instructions? ##########"
node -e '
const {Pool}=require("pg");require("dotenv").config();
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{try{
 const r=(await p.query("SELECT pl.id, pr.name, pl.label, pl.source, pl.bot_sku, (SELECT count(*)::int FROM inventory_items i WHERE i.plan_id=pl.id AND i.status=\x27available\x27) avail FROM product_plans pl JOIN products pr ON pr.id=pl.product_id WHERE pl.source=\x27inventory\x27 ORDER BY pr.name, pl.sort LIMIT 12")).rows;
 console.log("own-stock plans ("+r.length+"):");
 r.forEach(x=>console.log("  ["+x.id+"] "+x.name+" / "+x.label+"  sku="+(x.bot_sku||"-")+"  avail="+x.avail));
 const bp=(await p.query("SELECT sku, warranty_days, left(COALESCE(delivery_note,\x27\x27),60) note, left(COALESCE(retrieve,\x27\x27),40) retr FROM bot_products ORDER BY sku LIMIT 10")).rows;
 console.log("\nbot_products sample ("+bp.length+"):");
 bp.forEach(x=>console.log("  "+x.sku+"  warranty="+x.warranty_days+"  note="+JSON.stringify(x.note)+"  retrieve="+JSON.stringify(x.retr)));
}catch(e){console.log("ERR",e.message);} await p.end();})();' 2>&1 | head -40

echo
echo "########## D. Does products/product_plans have an instructions or warranty column of its own? ##########"
node -e '
const {Pool}=require("pg");require("dotenv").config();
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{try{
 const r=(await p.query("SELECT column_name,table_name FROM information_schema.columns WHERE table_name IN (\x27products\x27,\x27product_plans\x27,\x27bot_products\x27) AND (column_name ILIKE \x27%instruct%\x27 OR column_name ILIKE \x27%warrant%\x27 OR column_name ILIKE \x27%note%\x27 OR column_name ILIKE \x27%retrieve%\x27) ORDER BY table_name")).rows;
 r.forEach(x=>console.log("  "+x.table_name+"."+x.column_name));
}catch(e){console.log("ERR",e.message);} await p.end();})();' 2>&1 | head -20
