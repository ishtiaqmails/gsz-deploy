#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 11: asset cache-bump
#  RUN: cd /opt/gsz-deploy && git pull && bash step11.sh
#  Step 10's new app.css / app.js were cached by browsers under
#  ?v=9, so the motion + mobile-search weren't loading. Bump the
#  asset version in the shared header so fresh files are fetched.
#  Touches ONLY: views/partials/store_top.ejs + store_bottom.ejs.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -f "$APP/views/partials/store_top.ejs" ] || { echo "ABORT: store_top partial not found."; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"
echo "== Galaxy Subz x Zayron — Step 11 (asset cache-bump) · port $PORT =="
ts=$(date +%s)
cp -a "$APP/views/partials/store_top.ejs"    "$APP/views/partials/store_top.ejs.bak-step11.$ts"
cp -a "$APP/views/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs.bak-step11.$ts"

restore(){
  echo ">> rolling back Step 11"
  cp -a "$APP/views/partials/store_top.ejs.bak-step11.$ts"    "$APP/views/partials/store_top.ejs"
  cp -a "$APP/views/partials/store_bottom.ejs.bak-step11.$ts" "$APP/views/partials/store_bottom.ejs"
  pm2 restart gsz >/dev/null 2>&1 || true
}

cat > /tmp/gsz11_bump.js <<'GSZ_B_EOF'
const fs=require('fs');
['/opt/gsz/views/partials/store_top.ejs','/opt/gsz/views/partials/store_bottom.ejs'].forEach(function(f){
  let s=fs.readFileSync(f,'utf8');
  const before=s;
  s=s.replace(/(app\.(?:css|js))\?v=\d+/g,'$1?v=11');
  if(s!==before){fs.writeFileSync(f,s);console.log('bumped '+f);}
  else console.log('no version string in '+f+' (ok)');
});
GSZ_B_EOF
node /tmp/gsz11_bump.js || { restore; exit 1; }

pm2 restart gsz --update-env >/dev/null
sleep 1.6
HOME=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
if echo "$HOME" | grep -q 'app.css?v=11' && echo "$HOME" | grep -q 'app.js?v=11'; then
  echo "[ok] assets now served as ?v=11 — browsers will fetch fresh CSS/JS"
else
  echo "CHECK FAILED — rolling back"; restore; exit 1
fi
echo "============================================================"
echo " STEP 11 COMPLETE — hard-refresh the site; motion + mobile"
echo " search will now load. (Ctrl/Cmd+Shift+R if still cached.)"
echo " NEXT: Step 12 — product-page redesign."
echo "============================================================"
