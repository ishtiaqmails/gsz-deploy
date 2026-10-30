#!/usr/bin/env bash
# dumpVbot.sh — read-only. Locate the Verification Bot (pm2 process + its code) and how it
# handles incoming owner messages/commands, so the `price` command can be added. Also confirm
# the admin product editor has a USD price field.
set -uo pipefail

echo "### A) pm2 processes (name | cwd | script) ###"
pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{JSON.parse(d).forEach(p=>console.log("  "+p.name+"  |  "+((p.pm2_env&&p.pm2_env.pm_cwd)||"?")+"  |  "+(p.pm_exec_path||"?")))}catch(e){console.log("  (could not parse pm2 jlist: "+e.message+")")}})' 2>/dev/null || pm2 ls

echo
echo "### B) candidate bot dirs (anything with verify/wa/bot in the path under /opt or ~) ###"
ls -d /opt/*verif* /opt/*vbot* /opt/*wa* /opt/*bot* 2>/dev/null | head
echo "--- top-level JS in each candidate ---"
for d in $(pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const s=new Set();JSON.parse(d).forEach(p=>{const c=p.pm2_env&&p.pm2_env.pm_cwd;if(c)s.add(c)});console.log([...s].join(" "))}catch(e){}})' 2>/dev/null); do
  echo "  [$d]"; ls "$d"/*.js 2>/dev/null | head -12
done

echo
echo "### C) how the verification bot parses commands (search its code for a command handler) ###"
for d in $(pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const s=new Set();JSON.parse(d).forEach(p=>{const c=p.pm2_env&&p.pm2_env.pm_cwd;if(c)s.add(c)});console.log([...s].join(" "))}catch(e){}})' 2>/dev/null); do
  grep -rlnE "messages.upsert|conn.ev.on|sendMessage|body|startsWith|OWNER|owner" "$d" 2>/dev/null | grep -vE "node_modules|/\.git/" | head -6
done

echo
echo "### D) admin product editor — does it have a USD (\$) price field? ###"
grep -rnE "price_usd" /opt/gsz/views/admin/*product* /opt/gsz/routes/adminCatalog.js 2>/dev/null | grep -v node_modules | head -15
echo "== END =="
