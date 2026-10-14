#!/usr/bin/env bash
# stepNfFulfillProbe.sh — READ-ONLY. Map the Netflix auto-assign (fulfilment) path so I can
# confirm/finish it: which code creates nf_assignments on a paid order, how a Profile plan grabs
# a free inventory unit, and how a Full plan provisions from the Portal. Changes nothing.
set -u
GSZ=/opt/gsz; cd "$GSZ"

echo "=== nf_accounts + nf_assignments columns ==="
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  for(const t of ['nf_accounts','nf_assignments']){
    const c=(await p.query(\"SELECT column_name,data_type FROM information_schema.columns WHERE table_name=\$1 ORDER BY ordinal_position\",[t])).rows;
    console.log(t+': '+c.map(x=>x.column_name).join(', '));
  }
  const n=(await p.query(\"SELECT count(*) a,count(*) FILTER (WHERE plan_id IS NOT NULL) hp FROM nf_accounts\").catch(()=>({rows:[{a:'?',hp:'?'}]}))).rows[0];
  console.log('nf_accounts rows:', n.a);
  await p.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
"

echo ""
echo "=== code that writes nf_assignments (auto-assign at purchase) ==="
grep -rlE "INTO nf_assignments|nf_assignments\s*\(" --include=*.js . 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head

echo ""
echo "=== fulfilment / deliver / dispatch files ==="
ls -1 lib/ 2>/dev/null | grep -iE 'deliver|fulfil|dispatch|assign|netflix' | head
grep -rlE "fulfill|dispatch|deliverOrder|assignNetflix|nf_account" --include=*.js lib routes 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head

echo ""
F=$(grep -rlE "INTO nf_assignments|nf_assignments *\(" --include=*.js . 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head -1)
echo "ASSIGN FILE: ${F:-NOT FOUND}"
if [ -n "${F:-}" ]; then
  echo "--- how it picks a free unit / portal + inserts the assignment ---"
  grep -nE "nf_accounts|nf_assignments|source|nf_portal_product_id|plan_tier|portal|free|assigned|INSERT|UPDATE" "$F" | head -30
fi
