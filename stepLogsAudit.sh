#!/usr/bin/env bash
# stepLogsAudit.sh — READ ONLY. PM2 restart counts + error-log tails + crash/disconnect grep for gsz, gszwabot, gsz-iptv-worker.
set -uo pipefail

echo "===== PM2 status (high 'restarts' = crashing) ====="
pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{JSON.parse(d).forEach(p=>{var e=p.pm2_env||{};console.log((p.name||"").padEnd(18)+" status="+(e.status||"?")+"  restarts="+(e.restart_time||0)+"  unstable="+(e.unstable_restarts||0)+"  mem="+Math.round(((p.monit||{}).memory||0)/1048576)+"MB");});}catch(e){console.log("parse err "+e.message);}})'

for P in gsz gszwabot gsz-iptv-worker; do
  echo; echo "===== $P ====="
  EL=$(pm2 jlist 2>/dev/null | P="$P" node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{let p=JSON.parse(d).find(x=>x.name===process.env.P);process.stdout.write((p&&p.pm2_env&&p.pm2_env.pm_err_log_path)||"");}catch(e){}})')
  OL=$(pm2 jlist 2>/dev/null | P="$P" node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{let p=JSON.parse(d).find(x=>x.name===process.env.P);process.stdout.write((p&&p.pm2_env&&p.pm2_env.pm_out_log_path)||"");}catch(e){}})')
  if [ -z "${EL:-}" ]; then echo "(process not found)"; continue; fi
  echo "err log: $EL"
  if [ -f "$EL" ]; then echo "-- last 20 lines of ERROR log --"; tail -n 20 "$EL"; else echo "(no error log file)"; fi
  echo "-- crash/disconnect matches across err+out (last 18) --"
  grep -niE "uncaught|unhandled|throw|Error:|ECONNREFUSED|ETIMEDOUT|crash|fatal|logged out|Connection Closed|stream errored|conflict|428|440|401|restart" "$EL" "$OL" 2>/dev/null | tail -n 18
done
echo; echo "DONE-LOGS"
