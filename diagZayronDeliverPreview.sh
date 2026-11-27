#!/usr/bin/env bash
# diagZayronDeliverPreview — render the NEW delivery message for a recent delivered zayron IPTV order, to confirm the
# format + that Players come through from the reseller bot. READ-ONLY (sends nothing).
set +e
cd /opt/zayron || exit 0
node -e "
const {Pool}=require('pg');require('dotenv').config();
const p=new Pool();
const gszApi=require('./lib/gszApi');
const dm=require('./lib/deliveryMsg');
(async()=>{
  try{
    const rows=(await p.query(\"SELECT ref, plan_label, content_type, server_id, created_at FROM orders WHERE status='delivered' AND bot_job_id IS NOT NULL ORDER BY id DESC LIMIT 5\")).rows;
    if(!rows.length){console.log('(no delivered bot orders to preview)');return p.end();}
    for(const o of rows){
      let st=null; try{ st=await gszApi.orderStatus(o.ref); }catch(e){ st={err:e.message}; }
      const fields=(st&&st.fields)||{};
      let pn=''; try{ const sv=(await p.query('SELECT name FROM servers WHERE id=\$1',[o.server_id])).rows[0]; pn=sv&&sv.name||''; }catch(e){}
      console.log('===== '+o.ref+'  (bot status: '+((st&&st.status)||(st&&st.err)||'n/a')+') =====');
      console.log('fields.players present? '+ (Array.isArray(fields.players)?('yes ('+fields.players.length+')'):'no') + ' | fields.details: '+(Array.isArray(fields.details)?fields.details.length:0));
      const order={order_no:o.ref,created_at:o.created_at,product_name:pn,plan_label:o.plan_label};
      const m=dm.compose(order,fields,{siteName:'Zayron',salesNumber:'923141892712',siteUrl:'zayron.tv',versionLabel:o.content_type||''});
      console.log('----- MESSAGE -----');
      console.log(m.main);
      console.log('-------------------\n');
    }
  }catch(e){console.log('ERR',e.message);}
  await p.end();
})();" 2>&1 | tail -60
echo DONE
