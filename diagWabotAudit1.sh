#!/usr/bin/env bash
# diagWabotAudit1 — READ-ONLY reconnaissance for the Verification Bot deep-surgery scope.
# Nothing is changed. Maps: live bot.js state, every wa_template (key + size), the owner-command
# surface in the website webhook, the customer verification reply branches, and the require graph.
set +e
G=/opt/gsz; W=/opt/gsz-wabot
echo "############ 1. LIVE bot.js (the thin pipe) ############"
echo "-- bot.js lines: $(wc -l < $W/bot.js 2>/dev/null)"
grep -nc "sent-cache.json" $W/bot.js >/dev/null 2>&1 && echo "   retry-persist: PRESENT" || echo "   retry-persist: absent"
grep -q "unhandledRejection" $W/bot.js 2>/dev/null && echo "   error-guards: PRESENT" || echo "   error-guards: absent"
echo "-- webhook endpoint the bot posts to:"
grep -n "incoming\|WEBSITE_BASE\|postWebhook(" $W/bot.js 2>/dev/null | head

echo
echo "############ 2. WHERE the message logic lives (gsz website) ############"
echo "-- whatsapp route file(s):"
ls -la $G/routes/whatsapp*.js 2>/dev/null
echo "-- routes/whatsapp.js lines: $(wc -l < $G/routes/whatsapp.js 2>/dev/null)"
echo "-- libs it requires:"
grep -n "require(" $G/routes/whatsapp.js 2>/dev/null | grep -vi "express\|pg\|crypto\|path\|fs\b" | head -40

echo
echo "############ 3. OWNER-command surface (what owner typing does) ############"
echo "-- owner detection:"
grep -niE "isOwner|owner_number|ownerNumber|is_owner|OWNER_|adminNumber|owner_jid|owner_lid" $G/routes/whatsapp.js 2>/dev/null | head -20
echo "-- command routing (text ===, startsWith, switch, /cmd):"
grep -niE "text\s*===|startsWith\(|^\s*case |cmd ===|command ===|\.trim\(\)\.toLowerCase" $G/routes/whatsapp.js 2>/dev/null | head -80

echo
echo "############ 4. ALL wa_templates (key + body length only, no bodies yet) ############"
node -e '
const {Pool}=require("pg");require("dotenv").config();
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
p.query("SELECT key, length(body) AS len, left(regexp_replace(body,E\x27[\\n\\r]+\x27,\x27 ¶ \x27,\x27g\x27),90) AS preview FROM wa_templates ORDER BY key")
 .then(r=>{console.log("   "+r.rowCount+" templates:");r.rows.forEach(x=>console.log("   ["+String(x.len).padStart(4)+"] "+x.key+"  ::  "+x.preview));return p.end();})
 .catch(e=>{console.log("   templates ERR",e.message);process.exit(0);});' 2>&1 | head -80
echo
echo "-- wa_settings keys (config surface, values hidden if secret-ish):"
node -e '
const {Pool}=require("pg");require("dotenv").config();
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
p.query("SELECT key, CASE WHEN key ~* \x27secret|token|pass|key\x27 THEN \x27***\x27 ELSE left(value,60) END AS val FROM wa_settings ORDER BY key")
 .then(r=>{r.rows.forEach(x=>console.log("   "+x.key+" = "+(x.val||"(empty)")));return p.end();})
 .catch(e=>{console.log("   settings ERR",e.message);process.exit(0);});' 2>&1 | head -60

echo
echo "############ 5. OWNER feature keywords in whatsapp.js (menu/stock/orders/instructions/delivery) ############"
grep -niE "menu|stock|instruction|deliver|\bhelp\b|orders|sales|report|balance|credit|ownerhelp|command list" $G/routes/whatsapp.js 2>/dev/null | head -80
