#!/usr/bin/env bash
# diagWabotAudit2 — READ-ONLY. Copies the live message-logic files + a full template/settings dump
# into _audit/ and pushes them to the deploy repo so Claude can read them directly (no console paste).
# Changes NOTHING in /opt/gsz or the bot. If push fails, it prints the files so you can paste instead.
set +e
G=/opt/gsz; D=/opt/gsz-deploy; A="$D/_audit"
mkdir -p "$A"

# --- 1. copy the live source that generates every message ---
cp "$G/routes/whatsapp.js" "$A/whatsapp.js" && echo "copied whatsapp.js ($(wc -l < $A/whatsapp.js) lines)"
cp "$G/lib/watpl.js"       "$A/watpl.js"     2>/dev/null && echo "copied watpl.js ($(wc -l < $A/watpl.js) lines)"
cp "$G/lib/botapi.js"      "$A/botapi.js"    2>/dev/null && echo "copied botapi.js ($(wc -l < $A/botapi.js) lines)"

# --- 2. dump every template + non-secret setting (run with pg resolvable) ---
cat > "$A/_dump.js" <<'JS'
const {Pool}=require('pg');require('dotenv').config();
const fs=require('fs');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  try{
    const t=(await p.query("SELECT key,body FROM wa_templates ORDER BY key")).rows;
    let out=''; t.forEach(r=>{ out+='\n===== '+r.key+' =====\n'+(r.body||'')+'\n'; });
    fs.writeFileSync(process.argv[1], out);
    const s=(await p.query("SELECT key, CASE WHEN key ~* 'secret|token|pass' THEN '***' ELSE value END v FROM wa_settings ORDER BY key")).rows;
    let o2=''; s.forEach(r=>{ o2+=r.key+' = '+(r.v||'')+'\n'; });
    fs.writeFileSync(process.argv[2], o2);
    console.log('dumped '+t.length+' templates, '+s.length+' settings');
  }catch(e){ console.log('DUMP ERR', e.message); }
  await p.end();
})();
JS
( cd "$G" && NODE_PATH="$G/node_modules" node "$A/_dump.js" "$A/wa_templates.txt" "$A/wa_settings.txt" )
rm -f "$A/_dump.js"

# --- 3. commit + push so Claude can pull & read (no paste needed) ---
cd "$D"
git add _audit >/dev/null 2>&1
git -c user.email=bot@galaxyzayron.store -c user.name=gsz-audit commit -q -m "audit: live verification-bot message source + templates" 2>&1 | tail -1
echo "--- pushing ---"
git push origin HEAD 2>&1 | tail -5
PX=${PIPESTATUS[0]}
echo "PUSH_EXIT=$PX"
echo "--- staged files ---"
ls -la "$A"
[ "$PX" = "0" ] && echo "PUSH OK — tell Claude it's pushed." || echo "PUSH FAILED — I'll switch to console output; paste nothing yet."
