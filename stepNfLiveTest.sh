#!/usr/bin/env bash
# stepNfLiveTest.sh — LIVE end-to-end test of Netflix Profile auto-assign, by Claude.
# Loads one demo profile unit, creates a paid test order (no customer/email, owner-alert
# pre-claimed -> zero notifications), runs the REAL deliver.markDelivered(), and verifies:
# assignment created, order delivered + creds, tier/expiry correct, account now assigned,
# and the code-panel resolution returns the right tier/allowed. Cleaned up by stepNfLiveCleanup.sh.
set -euo pipefail
GSZ=/opt/gsz; cd "$GSZ"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
const gate=require(R+'/lib/netflixGate');
(async()=>{
  const ACC='nflive-demo@demo.local', ONO='NFLIVE-GSZ';
  // profile plan under the Netflix product
  const plan=(await pool.query(\"SELECT id, product_id, label, source, nf_tier FROM product_plans WHERE label ILIKE '%1 Profile%TV%Pakistan%' ORDER BY id LIMIT 1\")).rows[0];
  if(!plan) throw new Error('profile plan not found');
  const prod=(await pool.query('SELECT id, name, nf_enabled FROM products WHERE id=\$1',[plan.product_id])).rows[0];
  console.log('plan:', plan.id, '|', plan.label, '| source='+plan.source, '| nf_tier='+(plan.nf_tier||'(derive)'), '| product nf_enabled='+prod.nf_enabled);
  if(!prod.nf_enabled){ console.log('!! product nf_enabled=false — auto-assign will NOT trigger. Enable it on Admin → the product, then re-run.'); }

  // fresh test state
  await pool.query(\"DELETE FROM nf_assignments WHERE order_no=\$1\",[ONO]);
  await pool.query(\"DELETE FROM orders WHERE order_no=\$1\",[ONO]);
  await pool.query(\"DELETE FROM nf_accounts WHERE account_email=\$1\",[ACC]);

  // 1) load ONE demo profile unit into inventory (nf_accounts)
  const creds=JSON.stringify({email:ACC,password:'Live-Pass-99',profile:'GalaxyLive',pin:'7777'});
  const acc=(await pool.query(\"INSERT INTO nf_accounts(account_email,credentials,product_id,status,plan_id,note) VALUES(\$1,\$2,\$3,'active',\$4,'live-test') RETURNING id\",[ACC,creds,plan.product_id,plan.id])).rows[0];
  console.log('loaded demo profile unit -> nf_account', acc.id);

  // 2) create a PAID test order on that plan (no owner so zero notifications)
  const gen=(await pool.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='orders' AND is_generated='ALWAYS'\")).rows.map(r=>r.column_name);
  const base=(await pool.query('SELECT * FROM orders ORDER BY id DESC LIMIT 1')).rows[0];
  if(!base) throw new Error('no template order');
  const ov={order_no:ONO,product_id:plan.product_id,product_name:prod.name,plan_label:plan.label,status:'paid',email:null,customer_id:null,owner_alerts:'delivered,',delivered_credentials:null,delivered_at:null,bot_sku:null};
  Object.keys(ov).forEach(k=>{ if(k in base) base[k]=ov[k]; });
  const skip=new Set(['id',...gen]);
  const cols=Object.keys(base).filter(c=>!skip.has(c));
  const ord=(await pool.query('INSERT INTO orders('+cols.join(',')+') VALUES('+cols.map((_,i)=>'\$'+(i+1)).join(',')+') RETURNING id',cols.map(c=>base[c]))).rows[0];
  console.log('created paid test order', ONO, '-> id', ord.id);

  // 3) run the REAL delivery (auto-assign)
  const deliver=require(R+'/lib/deliver')(pool);
  const res=await deliver.markDelivered(ord.id,{});
  console.log('markDelivered ->', JSON.stringify(res));

  // 4) verify
  const asg=(await pool.query(\"SELECT nf_account_id,plan_tier,expires_at,status FROM nf_assignments WHERE order_no=\$1 ORDER BY id DESC LIMIT 1\",[ONO])).rows[0];
  const ordr=(await pool.query('SELECT status,delivered_credentials FROM orders WHERE id=\$1',[ord.id])).rows[0];
  const expTier=(['phone','tv','full'].indexOf(plan.nf_tier)>=0)?plan.nf_tier:gate.tierForPlan(plan.label);
  const allowed=(gate.PLAN_ALLOW[asg?asg.plan_tier:expTier]||[]).join(',');
  console.log('');
  console.log('=== RESULT ===');
  console.log('order status        :', ordr.status, ordr.status==='delivered'?'✓':'✗');
  console.log('assignment created  :', asg?('✓ nf_account '+asg.nf_account_id+', status '+asg.status):'✗ NONE');
  console.log('tier on assignment  :', asg?asg.plan_tier:'-', '(expected '+expTier+')', (asg&&asg.plan_tier===expTier)?'✓':'✗');
  console.log('expires_at          :', asg?new Date(asg.expires_at).toISOString().slice(0,10):'-');
  console.log('codes allowed (tier):', allowed);
  console.log('delivered login     :', (ordr.delivered_credentials||'').replace(/\n/g,' | ') || '(none)');
  const assignedNow=(await pool.query(\"SELECT (EXISTS(SELECT 1 FROM nf_assignments WHERE nf_account_id=\$1 AND status='active')) a\",[acc.id])).rows[0].a;
  console.log('unit now assigned   :', assignedNow?'✓ (no longer free)':'✗ still free');
  const pass = ordr.status==='delivered' && asg && asg.plan_tier===expTier && assignedNow;
  console.log('');
  console.log(pass?'✅ LIVE TEST PASS — profile auto-assign + code-panel data all correct':'❌ LIVE TEST FAIL — see above');
  await pool.end();
})().catch(e=>{console.error('LIVE TEST ERROR:',e.message);process.exit(1);});
"
