#!/usr/bin/env bash
# stepNfAssign.sh — wire Netflix auto-assign at delivery.
#   1) safety index: one active nf_assignment per account (bulletproofs profile claims)
#   2) patch lib/deliver.js (nf_enabled -> nfAssign: profile from inventory, full from Portal,
#      both create the nf_assignment the code panel reads)
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-nfasg-$TS"; cd "$GSZ"
DV=lib/deliver.js
mkdir -p "$BK/lib"; cp "$GSZ/$DV" "$BK/$DV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$DV" "$GSZ/$DV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> 1) safety index (one active assignment per account)"
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ await p.query(\"CREATE UNIQUE INDEX IF NOT EXISTS nf_asg_one_active ON nf_assignments(nf_account_id) WHERE status='active'\"); console.log('   index ready'); await p.end(); })().catch(e=>{console.error(e.message);process.exit(1);});
"

echo "==> 2) patch lib/deliver.js"
node "$SRC/patch_nfassign.js" "$GSZ"

echo "==> checks"
node --check "$GSZ/$DV" && echo "   deliver.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Netflix orders now auto-assign on delivery (profile from inventory, full from Portal) + create the code-panel assignment"
