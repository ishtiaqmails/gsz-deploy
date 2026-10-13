#!/usr/bin/env bash
# stepNfTest.sh — TEST ONLY. Creates a demo Netflix account + a test order (TV tier) assigned to it,
# keyed to the same customer as order GSZ-2008, so the hub Netflix panel can be verified end-to-end.
# Everything is tagged NFTEST-GSZ / nftest-gsz@demo.local and removed by stepNfTestCleanup.sh.
set -euo pipefail
GSZ=/opt/gsz; cd "$GSZ"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const nf=(await p.query(\"SELECT id FROM products WHERE slug='netflix-premium'\")).rows[0];
  if(!nf) throw new Error('netflix-premium product not found');
  const plan=(await p.query(\"SELECT id,label FROM product_plans WHERE product_id=\$1 AND label ILIKE '%TV%' AND label ILIKE '%Pakistan%' ORDER BY id LIMIT 1\",[nf.id])).rows[0];
  if(!plan) throw new Error('TV Pakistan plan not found');
  const g=(await p.query(\"SELECT customer_id,email FROM orders WHERE order_no='GSZ-2008'\")).rows[0];
  if(!g) throw new Error('GSZ-2008 not found');
  let cid=g.customer_id;
  if(!cid && g.email){ const c=(await p.query(\"SELECT id FROM customers WHERE lower(email)=lower(\$1) LIMIT 1\",[g.email])).rows[0]; if(c) cid=c.id; }
  // cid may stay null; the cloned test order inherits GSZ-2008's email, so it's still owned by you.
  // clean any prior test rows first (idempotent)
  await p.query(\"DELETE FROM nf_assignments WHERE order_no='NFTEST-GSZ'\");
  await p.query(\"DELETE FROM orders WHERE order_no='NFTEST-GSZ'\");
  await p.query(\"DELETE FROM nf_accounts WHERE account_email='nftest-gsz@demo.local'\");
  // demo Netflix account
  const creds=JSON.stringify({email:'nftest-gsz@demo.local',password:'Demo-Pass-123',profile:'Galaxy',pin:'4821'});
  const acc=(await p.query(\"INSERT INTO nf_accounts(account_email,credentials,product_id,plan_id,status) VALUES(\$1,\$2,\$3,\$4,'active') RETURNING id\",['nftest-gsz@demo.local',creds,nf.id,plan.id])).rows[0];
  // clone GSZ-2008 order row (satisfies all NOT NULL cols), override for Netflix; skip generated cols + id
  const gen=(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='orders' AND is_generated='ALWAYS'\")).rows.map(r=>r.column_name);
  const base=(await p.query(\"SELECT * FROM orders WHERE order_no='GSZ-2008'\")).rows[0];
  const skip=new Set(['id',...gen]);
  const ov={order_no:'NFTEST-GSZ',product_id:nf.id,product_name:'Netflix Premium',plan_label:plan.label,status:'delivered',bot_sku:null,credentials:null,delivered_credentials:null};
  Object.keys(ov).forEach(k=>{ if(k in base) base[k]=ov[k]; });
  const cols=Object.keys(base).filter(c=>!skip.has(c));
  const ord=(await p.query('INSERT INTO orders('+cols.join(',')+') VALUES('+cols.map((_,i)=>'\$'+(i+1)).join(',')+') RETURNING id', cols.map(c=>base[c]))).rows[0];
  if(cid!=null){ await p.query(\"INSERT INTO nf_assignments(nf_account_id,order_id,order_no,customer_id,plan_tier,status,expires_at) VALUES(\$1,\$2,'NFTEST-GSZ',\$3,'tv','active',now()+interval '30 days')\",[acc.id,ord.id,cid]); }
  else { await p.query(\"INSERT INTO nf_assignments(nf_account_id,order_id,order_no,plan_tier,status,expires_at) VALUES(\$1,\$2,'NFTEST-GSZ','tv','active',now()+interval '30 days')\",[acc.id,ord.id]); }
  console.log('TEST READY -> order NFTEST-GSZ | nf_account '+acc.id+' | customer '+(cid==null?'(by email)':cid)+' | plan \"'+plan.label+'\" (tv tier)');
  await p.end();
})().catch(e=>{console.error('TEST SETUP FAIL:',e.message);process.exit(1);});
"
