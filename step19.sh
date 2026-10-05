#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 19: premium polish (patch)
#  RUN: cd /opt/gsz-deploy && git pull && bash step19.sh
#   - Reviews: grid that fits -> NO horizontal scrollbar.
#   - "One trusted family of brands" bar is centered.
#   - Premium lift: glowing hero halo, brighter primary-button glow,
#     glowing category icons, bolder section headings.
#   - Exact-string patch of public/css/app.css (each change asserted once).
#  Asset version -> v=19. Auto-rollback on health-check failure.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views" ] || { echo "ABORT: $APP/views not found"; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"
echo "== Galaxy Subz x Zayron — Step 19 (premium polish) · port $PORT =="
ts=$(date +%s)
cp -a "$APP/public/css/app.css"              "$APP/public/css/app.css.bak-step19.$ts"
cp -a "$APP/views/partials/store_top.ejs"    "$APP/views/partials/store_top.ejs.bak-step19.$ts"
cp -a "$APP/views/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs.bak-step19.$ts"
restore(){
  echo ">> rolling back Step 19"
  cp -a "$APP/public/css/app.css.bak-step19.$ts"              "$APP/public/css/app.css"
  cp -a "$APP/views/partials/store_top.ejs.bak-step19.$ts"    "$APP/views/partials/store_top.ejs"
  cp -a "$APP/views/partials/store_bottom.ejs.bak-step19.$ts" "$APP/views/partials/store_bottom.ejs"
  pm2 restart gsz >/dev/null 2>&1 || true
}
cat > /tmp/gsz19_patch.js <<'GSZ_P19'
const fs=require('fs');
const f=process.argv[2];
let s=fs.readFileSync(f,'utf8');
let fail=0;
function rep(a,b,label){const n=s.split(a).length-1; if(n!==1){console.error('FAIL ['+label+'] matches='+n);fail=1;return;} s=s.replace(a,b); console.log('ok '+label);}

// 1) Reviews: grid that fits — NO horizontal scrollbar
rep('.rev-cards{display:flex;gap:16px;overflow-x:auto;min-width:0;padding:6px 2px 14px;scroll-snap-type:x mandatory;scrollbar-width:thin}',
   '.rev-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:16px}',
   'rev-cards grid');
rep('.rev{flex:0 0 300px;scroll-snap-align:start;background:var(--surface);',
   '.rev{background:var(--surface);',
   'rev no flex-basis');
rep('@media(max-width:520px){.rev{flex-basis:84vw}}',
   '@media(max-width:620px){.rev-cards{grid-template-columns:1fr}}',
   'rev mobile');

// 2) Centered trusted-family bar
rep('.house-in{display:flex;align-items:center;gap:22px;flex-wrap:wrap;padding:22px 0}',
   '.house-in{display:flex;align-items:center;justify-content:center;gap:22px;flex-wrap:wrap;padding:22px 0;text-align:center}',
   'house centered');

// 3) Premium hero glow halo
rep('.hero{position:relative;width:100%;padding:clamp(12px,1.8vw,22px) var(--gut) 0}',
   '.hero{position:relative;width:100%;padding:clamp(12px,1.8vw,22px) var(--gut) 0;isolation:isolate}\n.hero::before{content:"";position:absolute;left:50%;top:6%;width:min(1760px,92%);height:86%;transform:translateX(-50%);background:var(--brand);filter:blur(90px);opacity:.22;z-index:-1;border-radius:60px;pointer-events:none}',
   'hero glow');

// 4) Primary button premium glow
rep('.btn-primary{background:var(--brand);color:#fff;box-shadow:0 12px 26px -12px rgba(42,108,255,.85)}',
   '.btn-primary{background:var(--brand);color:#fff;box-shadow:0 14px 34px -12px rgba(59,130,255,.9),0 0 0 1px rgba(255,255,255,.08) inset}',
   'btn glow');

// 5) Category icon glow
rep('.cat-tile .cg{width:46px;height:46px;border-radius:13px;display:grid;place-items:center;flex:none;color:#fff;\n  background:linear-gradient(135deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}',
   '.cat-tile .cg{width:48px;height:48px;border-radius:13px;display:grid;place-items:center;flex:none;color:#fff;\n  background:linear-gradient(135deg,var(--g1,#2a6cff),var(--g2,#19c6ee));box-shadow:0 10px 24px -8px rgba(59,130,255,.6)}',
   'cat icon glow');

// 6) Bolder, more confident section headings
rep('.sec-head h2{font-family:var(--display);font-weight:800;font-size:clamp(24px,3vw,34px);letter-spacing:-.02em;margin:6px 0 0;line-height:1.05}',
   '.sec-head h2{font-family:var(--display);font-weight:800;font-size:clamp(26px,3.4vw,42px);letter-spacing:-.025em;margin:6px 0 0;line-height:1.03}',
   'section h2');

if(fail){console.error('PATCHES FAILED');process.exit(1);}
fs.writeFileSync(f,s);
console.log('[ok] all patches applied');
GSZ_P19
node /tmp/gsz19_patch.js "$APP/public/css/app.css" || { restore; exit 1; }

cat > /tmp/gsz19_bump.js <<'GSZ_B19'
const fs=require('fs');
['/opt/gsz/views/partials/store_top.ejs','/opt/gsz/views/partials/store_bottom.ejs'].forEach(function(f){
  let s=fs.readFileSync(f,'utf8');s=s.replace(/(app\.(?:css|js))\?v=\d+/g,'$1?v=19');fs.writeFileSync(f,s);
});
console.log('[ok] asset version -> v=19');
GSZ_B19
node /tmp/gsz19_bump.js || { restore; exit 1; }
echo "[ok] patched"

pm2 restart gsz --update-env >/dev/null
sleep 2
OKALL=1
HEALTH=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health")
HOME_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/")
HB=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
CSS=$(curl -fsS "http://127.0.0.1:$PORT/static/css/app.css?v=19" || true)
[ "$HEALTH" = "200" ]                       || { echo "FAIL: health $HEALTH"; OKALL=0; }
[ "$HOME_CODE" = "200" ]                     || { echo "FAIL: home $HOME_CODE"; OKALL=0; }
grep -q 'app.css?v=19' <<< "$HB"             || { echo "FAIL: version not bumped"; OKALL=0; }
grep -q 'repeat(auto-fit,minmax(230px,1fr))' <<< "$CSS" || { echo "FAIL: reviews grid not applied"; OKALL=0; }
grep -q 'justify-content:center;gap:22px'    <<< "$CSS" || { echo "FAIL: house center not applied"; OKALL=0; }
grep -q 'hero::before'                        <<< "$CSS" || { echo "FAIL: hero glow not applied"; OKALL=0; }
if [ "$OKALL" != "1" ]; then echo "CHECK FAILED — rolling back"; restore; pm2 logs gsz --lines 20 --nostream || true; exit 1; fi
echo "============================================================"
echo "  STEP 19 OK — hard-refresh once (Ctrl+Shift+R)"
echo "  - Reviews scrollbar gone; trusted-family bar centered."
echo "  - Hero glow, button + icon glow, bolder headings."
echo "============================================================"
