#!/usr/bin/env bash
# stepPreMsgRestore.sh <backup.json> — restore the two WhatsApp template bodies from a backup
# written by stepPreMsg.sh. (deliver.js itself is restored from its .bak-premsg-* dir if needed.)
set -euo pipefail
GSZ=/opt/gsz; BK="${1:-}"
[ -z "$BK" ] && { echo "usage: bash stepPreMsgRestore.sh <path-to-wa_templates.bak.json>"; exit 1; }
[ -f "$BK" ] || { echo "backup not found: $BK"; exit 1; }
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');const fs=require('fs');
const bk=JSON.parse(fs.readFileSync('$BK','utf8'));
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ let n=0; for(const k of Object.keys(bk)){ if(bk[k]!=null){ await p.query('UPDATE wa_templates SET body=\$1 WHERE key=\$2',[bk[k],k]); n++; } } console.log('restored '+n+' templates'); await p.end(); })().catch(e=>{console.error(e.message);process.exit(1);});
"
echo "restored. run: pm2 restart gsz"
