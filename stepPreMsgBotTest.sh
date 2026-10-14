#!/usr/bin/env bash
# stepPreMsgBotTest.sh — DRY RUN (no messages sent). For recent delivered bot orders, replicate
# exactly what the delivery path now composes (bot fields + website How-to-Use/Warranty) and PRINT
# the premium main + follow-up, so you can verify the live output before any real order goes out.
set -u
GSZ=/opt/gsz; cd "$GSZ"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const botapi=require(R+'/lib/botapi');
const deliveryMsg=require(R+'/lib/deliveryMsg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const sset=(await pool.query(\"SELECT value FROM wa_settings WHERE key='wa_sales_number'\")).rows[0]||{};
  const sales=String(sset.value||'').replace(/[^0-9]/g,'');
  const rows=(await pool.query(\"SELECT * FROM orders WHERE source='bot' AND status IN ('delivered','completed') ORDER BY id DESC LIMIT 4\")).rows;
  if(!rows.length){ console.log('no delivered bot orders'); await pool.end(); return; }
  for(const o of rows){
    let f=null; try{ const st=await botapi.orderStatus(o.order_no); f=st&&st.fields; }catch(e){}
    console.log('\\n==================== '+o.order_no+'  ('+o.product_name+') ====================');
    if(!f||!f.delivery_type){ console.log('(no fields -> would FALL BACK to raw bot text)'); continue; }
    const pr=(await pool.query('SELECT instructions, warranty FROM products WHERE id=\$1',[o.product_id])).rows[0]||{};
    const plw=(await pool.query('SELECT warranty, delivery_instructions FROM product_plans WHERE product_id=\$1 AND label=\$2 ORDER BY sort,id LIMIT 1',[o.product_id,o.plan_label])).rows[0]||{};
    const instr=((plw.delivery_instructions||'').trim())||(pr.instructions||'');
    const warr=((plw.warranty||'').trim())||(pr.warranty||'');
    const m=deliveryMsg.compose(o,f,{siteName:'Galaxy Subz × Zayron',salesNumber:sales,instructions:instr,warranty:warr});
    console.log('----- MAIN -----'); console.log(m.main);
    if(m.followup){ console.log('\\n----- FOLLOW-UP -----'); console.log(m.followup); }
    else console.log('\\n(no follow-up — set How-to-Use/Warranty for this product in admin to add one)');
  }
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
"
