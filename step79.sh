#!/usr/bin/env bash
# step79 — WhatsApp module Phase 2c: install/refresh the dedicated Baileys
# verification bot at /opt/gsz-wabot. Does NOT touch the gsz site.
# Usage:
#   bash step79.sh                 # install/refresh bot (number unchanged)
#   bash step79.sh 923XXXXXXXXX    # also set the verification number
set -euo pipefail
GSZ=/opt/gsz
BOT=/opt/gsz-wabot
SRC=/opt/gsz-deploy/wabot
VNUM_ARG="${1:-}"

[ -f "$SRC/bot.js" ] || { echo "!! $SRC/bot.js missing — did 'git pull' run in /opt/gsz-deploy?"; exit 1; }

echo "==> node version check"
NODEMAJ=$(node -e "console.log(process.versions.node.split('.')[0])")
echo "   node $(node -v)"
[ "$NODEMAJ" -ge 20 ] || echo "   !! WARNING: Baileys prefers Node 20+. If the bot fails to start, upgrade Node."

echo "==> place bot files at $BOT (preserving .env + auth/)"
mkdir -p "$BOT"
cp "$SRC/bot.js" "$BOT/bot.js"
cp "$SRC/package.json" "$BOT/package.json"
cp -n "$SRC/.env.example" "$BOT/.env.example" 2>/dev/null || true
[ -f "$BOT/.env" ] || cp "$SRC/.env.example" "$BOT/.env"

echo "==> read webhook secret from the website (wa_settings)"
SECRET=$(cd "$GSZ" && node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
p.query("SELECT value FROM wa_settings WHERE key='wa_bot_webhook_secret'").then(r=>{ process.stdout.write(r.rows[0]?r.rows[0].value:''); return p.end(); }).catch(()=>{ p.end(); });
NODE
)
[ -n "$SECRET" ] || { echo "!! could not read wa_bot_webhook_secret (is step77 deployed?)"; exit 1; }
echo "   secret loaded (${#SECRET} chars)"

echo "==> write $BOT/.env (secret + base URL + port)"
SECRET="$SECRET" ENVF="$BOT/.env" node <<'NODE'
const fs=require('fs'); const f=process.env.ENVF; let s=fs.readFileSync(f,'utf8');
const set=(k,v)=>{ const re=new RegExp('^'+k+'=.*','m'); s = re.test(s) ? s.replace(re, k+'='+v) : (s.replace(/\s*$/,'')+'\n'+k+'='+v+'\n'); };
set('WA_WEBHOOK_SECRET', process.env.SECRET);
if(!/^WEBSITE_BASE=.+/m.test(s)) set('WEBSITE_BASE','http://127.0.0.1:3900');
if(!/^BOT_PORT=.+/m.test(s)) set('BOT_PORT','8095');
fs.writeFileSync(f,s);
NODE

# seed the bot send URL (website -> bot) and optionally the verification number
if [ -n "$VNUM_ARG" ]; then VNUM_CLEAN=$(printf '%s' "$VNUM_ARG" | tr -cd '0-9'); else VNUM_CLEAN=""; fi
( cd "$GSZ" && VNUM="$VNUM_CLEAN" node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{
  await p.query("INSERT INTO wa_settings(key,value) VALUES('wa_bot_send_url','http://127.0.0.1:8095/send') ON CONFLICT(key) DO NOTHING");
  const v = process.env.VNUM || '';
  if (v) { await p.query("INSERT INTO wa_settings(key,value) VALUES('wa_verify_number',$1) ON CONFLICT(key) DO UPDATE SET value=$1, updated_at=now()", [v]); console.log('   verify number set to '+v); }
  else { console.log('   verify number unchanged (pass it as an arg to set it)'); }
  await p.end();
})().catch(e=>{ console.error('   db note: '+e.message); p.end(); });
NODE
)

echo "==> npm install (this can take a minute)"
( cd "$BOT" && npm install --no-audit --no-fund ) 2>&1 | tail -6

echo "==> node --check bot.js"; node --check "$BOT/bot.js"

echo "==> start under pm2 (name: gszwabot)"
if pm2 describe gszwabot >/dev/null 2>&1; then ( cd "$BOT" && pm2 restart gszwabot --update-env >/dev/null ); echo "   restarted"; else ( cd "$BOT" && pm2 start bot.js --name gszwabot >/dev/null ); echo "   started"; fi
pm2 save >/dev/null 2>&1 || true
sleep 2

echo "==> step79 OK — verification bot installed at $BOT"
echo
echo "NEXT — scan the WhatsApp QR with your spare verification number:"
echo "   pm2 logs gszwabot --lines 40"
echo "Scan the QR shown there. When it prints '[wabot] connected as ...', it's live."
echo "If you did NOT pass the number, set it with:"
echo "   bash step79.sh <your_verification_number>"
