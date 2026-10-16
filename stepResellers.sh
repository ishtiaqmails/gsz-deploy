#!/usr/bin/env bash
# stepResellers.sh — admin-controllable Reseller Panels + dark public /resellers page with the credit scroller.
#   DB: reseller_panels table.  New: routes/adminResellers.js, views/admin/resellers.ejs.
#   Rewrites views/resellers.ejs. Patches server.js (mount), routes/pages.js (load panels), admin nav.
# Idempotent; restores on failure.
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-resellers-$TS"; cd "$GSZ"
SV=server.js; PG=routes/pages.js; NAV=views/admin/_shell_top.ejs; PUB=views/resellers.ejs
AR=routes/adminResellers.js; AV=views/admin/resellers.ejs
mkdir -p "$BK/routes" "$BK/views/admin"
cp "$GSZ/$SV" "$BK/$SV"; cp "$GSZ/$PG" "$BK/$PG"; cp "$GSZ/$NAV" "$BK/$NAV"; cp "$GSZ/$PUB" "$BK/$PUB"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$SV" "$GSZ/$SV"; cp "$BK/$PG" "$GSZ/$PG"; cp "$BK/$NAV" "$GSZ/$NAV"; cp "$BK/$PUB" "$GSZ/$PUB"; rm -f "$GSZ/$AR" "$GSZ/$AV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> DB: create reseller_panels"
node - "$GSZ" <<'NODE'
const R=process.argv[2];
require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const {Pool}=require(R+'/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  await pool.query(`CREATE TABLE IF NOT EXISTS reseller_panels (
    id serial PRIMARY KEY,
    name text NOT NULL,
    badge text,
    tagline text,
    features jsonb NOT NULL DEFAULT '[]'::jsonb,
    image_url text,
    wa_text text,
    currency text NOT NULL DEFAULT 'PKR',
    tiers jsonb NOT NULL DEFAULT '[]'::jsonb,
    active boolean NOT NULL DEFAULT true,
    sort int NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
  )`);
  const cols=(await pool.query("SELECT column_name FROM information_schema.columns WHERE table_name='reseller_panels' ORDER BY ordinal_position")).rows.map(r=>r.column_name);
  console.log('   reseller_panels columns: '+cols.join(', '));
  await pool.end();
})().catch(e=>{console.error('   DB FAIL',e.message);process.exit(1);});
NODE

echo "==> deploy new files + rewrite public page"
cp -f "$SRC/adminResellers.js"   "$GSZ/$AR"
cp -f "$SRC/admin_resellers.ejs" "$GSZ/$AV"
cp -f "$SRC/resellers_page.ejs"  "$GSZ/$PUB"

echo "==> patch server.js + pages.js + admin nav"
node "$SRC/patch_resellers.js" "$GSZ"

echo "==> validate"
node --check "$GSZ/$SV" && echo "   server.js ok"
node --check "$GSZ/$PG" && echo "   pages.js ok"
node --check "$GSZ/$AR" && echo "   adminResellers.js ok"
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');['$GSZ/$PUB','$GSZ/$AV','$GSZ/$NAV'].forEach(function(f){ejs.compile(fs.readFileSync(f,'utf8'),{filename:f});});console.log('   views compile');"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "   health OK (${i}s)"; break; }; sleep 1; done
curl -s -o /dev/null -w '   /resellers -> %{http_code}\n' http://127.0.0.1:3900/resellers || true
curl -s -o /dev/null -w '   /admin/resellers -> %{http_code} (302=login redirect is expected)\n' http://127.0.0.1:3900/admin/resellers || true
echo "DONE — Admin → Reseller Panels manages the cards; /resellers renders them dark with the credit scroller + WhatsApp. Empty until you add a panel."
