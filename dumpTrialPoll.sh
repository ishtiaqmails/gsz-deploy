#!/usr/bin/env bash
# dumpTrialPoll.sh — read-only. Is the trial poller running? What does the bot say about the claim?
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "### A) is a trial poller wired/running? (like botsync was not) ###"
grep -rnE "trialpoll|trialPoll|trial-status|trialStatus|poll|setInterval" "$GSZ"/server.js "$GSZ"/lib/trialpoll.js "$GSZ"/lib 2>/dev/null | grep -v node_modules | grep -iE "trial|poll|setInterval" | head -20
echo "--- is trialpoll required in server.js? ---"
grep -nE "trialpoll|trialPoll|startTrial|trials.*poll" "$GSZ"/server.js 2>/dev/null | head

echo
echo "### B) latest trial claims + what the BOT says about them ###"
node - "$GSZ" <<'NODE' 2>&1 | head -30
const R=process.argv[2];
try{require(R+'/node_modules/dotenv').config({path:R+'/.env'});}catch(e){}
const {Pool}=require(R+'/node_modules/pg'); const E=process.env;
const botapi=require(R+'/lib/botapi');
let pool; try{ pool = E.DATABASE_URL?new Pool({connectionString:E.DATABASE_URL}):(E.DB_HOST||E.DB_NAME?new Pool({host:E.DB_HOST||'127.0.0.1',port:+(E.DB_PORT||5432),user:E.DB_USER||E.PGUSER,password:(E.DB_PASS||E.DB_PASSWORD||E.PGPASSWORD||'')+'',database:E.DB_NAME||E.PGDATABASE}):new Pool()); }catch(e){console.log('pool',e.message);}
(async()=>{ try{
  const r=await pool.query("SELECT id,trial_type,status,bot_ref,LEFT(COALESCE(credentials,''),20) cred,claimed_at FROM trial_claims ORDER BY id DESC LIMIT 5");
  for (const x of r.rows){
    console.log('  claim#'+x.id+' type='+x.trial_type+' status='+x.status+' ref='+(x.bot_ref||'-')+' cred='+(x.cred||'(none)')+' at='+(x.claimed_at?new Date(x.claimed_at).toISOString().slice(0,16):'-'));
    if (x.bot_ref && botapi.configured && botapi.configured()){
      try{ const st=await botapi.trialStatus(x.bot_ref); console.log('      bot trial-status: '+JSON.stringify(st).slice(0,300)); }
      catch(e){ console.log('      bot trial-status ERR: '+e.message); }
    }
  }
}catch(e){console.log('  db err:',e.message);} try{await pool.end();}catch(e){} })();
NODE
echo "== END =="
