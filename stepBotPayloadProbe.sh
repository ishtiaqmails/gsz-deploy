#!/usr/bin/env bash
# stepBotPayloadProbe.sh — READ-ONLY. What does the reseller bot hand back to the website on
# delivery? Dump the bot client (lib/botapi.js) and the fulfilment/poll handler in checkout.js
# that stores delivered_credentials — so I can see if IPTV DNS/M3U/players come as structured
# fields or a text blob, and build the website's premium composition from the real data.
set -u
GSZ=/opt/gsz; cd "$GSZ"

echo "########## lib/botapi.js (bot client) ##########"
[ -f lib/botapi.js ] && { echo "lines: $(wc -l < lib/botapi.js)"; grep -nE "exports\.|function |claim|renew|poll|status|deliver|payload|credentials|dns|m3u|player|url|username|password|fields|result" lib/botapi.js | head -45; } || echo "not found"

echo ""
echo "########## checkout.js — pollOnce + bot delivery result handling (lines 165-300) ##########"
sed -n '165,300p' routes/checkout.js

echo ""
echo "########## a recently delivered BOT order — what got stored ##########"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const r=(await p.query(\"SELECT order_no, product_name, plan_label, source, bot_type, left(delivered_credentials, 500) dc, fields FROM orders WHERE source='bot' AND delivered_credentials IS NOT NULL ORDER BY id DESC LIMIT 2\")).rows;
  r.forEach(o=>{ console.log('--- '+o.order_no+' | '+o.product_name+' | '+(o.plan_label||'')+' | bot_type='+(o.bot_type||'')+' ---'); console.log('delivered_credentials:'); console.log(o.dc||'(none)'); console.log('fields:', JSON.stringify(o.fields||{}).slice(0,400)); console.log(''); });
  if(!r.length) console.log('(no delivered bot orders yet)');
  await p.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
"
