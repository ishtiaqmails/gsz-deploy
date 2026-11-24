#!/usr/bin/env bash
# diagGszDeliver2 — why order #43 is stuck at 'delivering': the generated line, the customer's number,
# the LIVE delivery/send code, and the worker logs. READ-ONLY.
set +e
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ order #43 (delivery fields) + customer 54 ############"
node - <<'NODE'
const {Pool}=require("pg");const fs=require("fs");
const env={};try{fs.readFileSync(".env","utf8").split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/);if(m)env[m[1]]=m[2].replace(/^["']|["']$/g,"").trim();});}catch(e){}
const p=new Pool({host:env.DB_HOST||"127.0.0.1",port:+(env.DB_PORT||5432),user:env.DB_USER,password:env.DB_PASS||env.DB_PASSWORD,database:env.DB_NAME});
(async()=>{try{
  const o=(await p.query("SELECT * FROM orders WHERE id=43")).rows[0]||{};
  const show=["id","order_no","status","whatsapp","email","product_name","plan_label","bot_sku","bot_plan_key","bot_type","bot_order_id","claim_result","verified_at","delivered_at","created_at","owner_alerts"];
  const s={};show.forEach(k=>{if(o[k]!==undefined)s[k]=o[k];});
  console.log("order43:",JSON.stringify(s,null,1));
  const dc=o.delivered_credentials; console.log("delivered_credentials:", dc?("[len "+String(dc).length+"] "+String(dc).slice(0,300)):"(null)");
  const bf=o.bot_fields; console.log("bot_fields:", bf?("[len "+String(JSON.stringify(bf)).length+"] "+JSON.stringify(bf).slice(0,300)):"(null)");
  const c=(await p.query("SELECT id,whatsapp,email,name FROM customers WHERE id=$1",[o.customer_id])).rows[0]||{};
  console.log("customer54:",JSON.stringify(c));
}catch(e){console.log("db err:",e.message)}process.exit(0)})();
NODE
echo
echo "############ LIVE code: status 'delivering' -> 'delivered' + WhatsApp send (exclude .bak) ############"
grep -rn "delivering\|'delivered'\|\"delivered\"\|deliverOrder\|sendDelivery\|notifyDeliver" --include=*.js . 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head -30
echo
echo "############ LIVE WhatsApp sender (exclude .bak) ############"
grep -rln "gszwabot\|wabot\|/send\|sendText\|sendMessage\|waSend\|8090" --include=*.js . 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head
echo
echo "############ lib/ files ############"
ls -la lib/ 2>/dev/null | grep -iE "deliver|worker|wa|bot|notify|send" || ls lib/ 2>/dev/null | head -40
echo
echo "############ gsz-iptv-worker logs (last 120) ############"
pm2 logs gsz-iptv-worker --lines 120 --nostream 2>/dev/null | tail -120
echo DONE
