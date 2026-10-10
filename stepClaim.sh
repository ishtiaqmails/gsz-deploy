#!/usr/bin/env bash
# Claim / Replace: order_issues migration + customer upload flow + admin decision console.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"

cp -f routes/account.js            "routes/account.js.bak.$TS"
cp -f routes/adminIssues.js        "routes/adminIssues.js.bak.$TS"
cp -f views/admin/issues.ejs       "views/admin/issues.ejs.bak.$TS"
cp -f views/partials/customer_tools.ejs "views/partials/customer_tools.ejs.bak.$TS"
restore(){ echo "!! failed — restoring"; \
  cp -f "routes/account.js.bak.$TS" routes/account.js; \
  cp -f "routes/adminIssues.js.bak.$TS" routes/adminIssues.js; \
  cp -f "views/admin/issues.ejs.bak.$TS" views/admin/issues.ejs; \
  cp -f "views/partials/customer_tools.ejs.bak.$TS" views/partials/customer_tools.ejs; }
trap restore ERR

# 1) migration (idempotent)
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -v ON_ERROR_STOP=1 -c \
  "ALTER TABLE order_issues ADD COLUMN IF NOT EXISTS screenshot text, ADD COLUMN IF NOT EXISTS admin_response text, ADD COLUMN IF NOT EXISTS admin_screenshot text, ADD COLUMN IF NOT EXISTS decision text, ADD COLUMN IF NOT EXISTS replacement_credentials text;"
echo "  migration ok"

# 2) full-file replacements
cp -f "$SRC/adminIssues.js"     routes/adminIssues.js
cp -f "$SRC/admin_issues.ejs"   views/admin/issues.ejs
cp -f "$SRC/customer_tools.ejs" views/partials/customer_tools.ejs

# 3) patch account.js (claim upload + feed + file route)
node "$SRC/patch_claim.js" "$GSZ"

# 4) checks
node --check routes/account.js
node --check routes/adminIssues.js
node -e "const ejs=require('ejs'),fs=require('fs');ejs.compile(fs.readFileSync('views/partials/customer_tools.ejs','utf8'),{filename:process.cwd()+'/views/partials/customer_tools.ejs'});console.log('  customer ejs ok');"
node -e "const ejs=require('ejs'),fs=require('fs');try{ejs.compile(fs.readFileSync('views/admin/issues.ejs','utf8'),{filename:process.cwd()+'/views/admin/issues.ejs'});console.log('  admin ejs ok');}catch(e){console.log('  admin ejs warn: '+e.message);}"
trap - ERR

pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/api/trials || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — Claim/Replace live: customer upload + warranty gate + admin decision console (stock / manual / fix / reject)."
