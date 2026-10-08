#!/usr/bin/env bash
# dumpP3 — live bot durations for the player SKUs (env loaded so botapi is configured)
GSZ=/opt/gsz; cd "$GSZ"
NODE_PATH="$GSZ/node_modules" node -e "
require('dotenv').config({path:'$GSZ/.env'});
const b=require('$GSZ/lib/botapi.js');
(async()=>{
  if(!b.configured()){console.log('botapi NOT configured (env missing GSZ_BOT_API_URL/KEY)');return;}
  try{
    const list=await b.getProducts(true);
    const want=['SKU-00141','SKU-00119','SKU-00144'];
    list.filter(x=>want.includes(x.sku||x.id)).forEach(x=>{
      console.log('==================');
      console.log('SKU:',x.sku||x.id,'| name:',x.name,'| delivery:',x.delivery_type||x.type);
      const plans=x.plans||x.durations||x.options||[];
      console.log('plans('+plans.length+'):',JSON.stringify(plans,null,1));
      if(x.types&&x.types.length)console.log('types:',JSON.stringify(x.types));
    });
    const missing=want.filter(w=>!list.some(x=>(x.sku||x.id)===w));
    if(missing.length)console.log('NOT in /api/products:',missing.join(', '));
  }catch(e){console.log('ERR',e.message);}
})();
"
