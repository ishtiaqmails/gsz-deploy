#!/usr/bin/env bash
# dumpBotSync3.sh — read-only. The sync trigger route + whether the bot API returns new products.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "###### A) routes/botAdmin.js (sync route + any button/interval) ######"
cat -n "$GSZ/routes/botAdmin.js" | head -80

echo
echo "###### B) is there ANY auto-sync anywhere (interval/startup/cron)? ######"
grep -rnE "syncProducts|botsync" "$GSZ"/server.js "$GSZ"/lib "$GSZ"/routes 2>/dev/null | grep -v node_modules | grep -v "lib/botsync.js:" | head
grep -rnE "setInterval|setTimeout\(.*sync|cron" "$GSZ"/server.js 2>/dev/null | head

echo
echo "###### C) a 'sync' button in the admin UI? ######"
grep -rniE "bot/sync|sync.*product|resync|refresh.*catalog|syncProducts|/admin/bot" "$GSZ"/views 2>/dev/null | head

echo
echo "###### D) LIVE: what the bot API returns right now (no DB needed) ######"
node - "$GSZ" <<'NODE' 2>&1 | head -40
const R=process.argv[2];
try{ require(R+'/node_modules/dotenv').config({path:R+'/.env'}); }catch(e){}
const botapi=require(R+'/lib/botapi');
(async()=>{
  console.log('configured:', botapi.configured());
  try {
    const list = await botapi.getProducts(true);
    console.log('bot returned products:', (list||[]).length);
    (list||[]).forEach(p=>{
      const sku=(p.sku!=null&&String(p.sku).trim())||(p.code!=null&&String(p.code).trim())||(p.id!=null?String(p.id):'?');
      console.log('  sku='+sku+' | '+String(p.name||'').slice(0,30)+' | is_active='+(p.is_active!==false)+' | type='+(p.delivery_type||'-'));
    });
  } catch(e){ console.log('getProducts err:', e.message); }
})();
NODE
echo "== END =="
