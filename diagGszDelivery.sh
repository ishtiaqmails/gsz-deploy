#!/usr/bin/env bash
# diagGszDelivery — galaxyzayron (/opt/gsz) delivery failure: a paid+generated line didn't reach the
# customer's WhatsApp. Find the order, the delivery-sender code, and recent errors. READ-ONLY.
set +e
echo "############ pm2 processes ############"
pm2 list 2>/dev/null | sed -n '1,40p'
echo
cd /opt/gsz 2>/dev/null || { echo "no /opt/gsz"; exit 0; }
echo "############ recent orders (last 6) ############"
node - <<'NODE'
const {Pool}=require("pg");const fs=require("fs");
const env={};try{fs.readFileSync(".env","utf8").split(/\r?\n/).forEach(l=>{const m=l.match(/^([A-Z0-9_]+)\s*=\s*(.*)$/);if(m)env[m[1]]=m[2].replace(/^["']|["']$/g,"").trim();});}catch(e){}
const p=new Pool({host:env.DB_HOST||"127.0.0.1",port:+(env.DB_PORT||5432),user:env.DB_USER,password:env.DB_PASS||env.DB_PASSWORD,database:env.DB_NAME});
(async()=>{try{
  const cols=(await p.query("SELECT column_name FROM information_schema.columns WHERE table_name='orders' ORDER BY ordinal_position")).rows.map(x=>x.column_name);
  console.log("orders cols:",cols.join(", "));
  const r=(await p.query("SELECT * FROM orders ORDER BY id DESC LIMIT 6")).rows;
  const keys=["id","ref","status","phone","customer_phone","customer_id","plan_label","product_name","server_name","line_user","line_url","delivered","delivered_at","notified","wa_sent","notify_sent","bot_job_id","created_at","updated_at"];
  r.forEach(o=>{const s={};keys.forEach(k=>{if(o[k]!==undefined)s[k]=o[k];});console.log(JSON.stringify(s));});
}catch(e){console.log("db err:",e.message)}process.exit(0)})();
NODE
echo
echo "############ WhatsApp delivery sender files ############"
grep -rln "notifyDelivered\|deliverLine\|sendLine\|waSend\|sendWhatsapp\|wasend\|is ready\|your order" --include=*.js . 2>/dev/null | grep -v node_modules | head
echo
echo "############ the deliver/notify code (how the line is sent to WhatsApp) ############"
grep -rn "notifyDelivered\|order.*ready\|is ready\|waSend\|wa.send\|sendText\|/send\b" --include=*.js . 2>/dev/null | grep -v node_modules | head -25
echo DONE
