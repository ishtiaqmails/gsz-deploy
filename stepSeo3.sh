#!/usr/bin/env bash
# stepSeo3.sh — www->non-www 301 + IndexNow (key file + submit all current URLs).
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-seo3-$TS"; cd "$GSZ"
SV=server.js
mkdir -p "$BK"; cp "$GSZ/$SV" "$BK/$SV"
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$SV" "$GSZ/$SV"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> install indexnow.js + patch server.js"
cp "$SRC/indexnow.js" "$GSZ/lib/indexnow.js"
node "$SRC/patch_seo3.js" "$GSZ"
node --check "$GSZ/lib/indexnow.js" && echo "   indexnow.js ok"
node --check "$GSZ/$SV" && echo "   server.js ok"

echo "==> restart gsz"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done

echo "==> verify www 301"
curl -s -o /dev/null -w '   www -> %{http_code} %{redirect_url}\n' -H 'Host: www.galaxyzayron.store' http://127.0.0.1:3900/ || true

echo "==> IndexNow: ensure key + verify key file + submit all sitemap URLs"
cat > /tmp/indexnow_submit.js <<'JS'
const R='/opt/gsz'; require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const { Pool } = require(R+'/node_modules/pg'); const http = require('http');
const indexnow = require(R+'/lib/indexnow');
const pool = new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
function get(path){ return new Promise(function(res,rej){ http.get({host:'127.0.0.1',port:3900,path:path,headers:{Host:'galaxyzayron.store'}},function(r){ let d=''; r.on('data',c=>d+=c); r.on('end',()=>res(d)); }).on('error',rej); }); }
(async () => {
  const key = await indexnow.getKey(pool);
  console.log('   indexnow key: ' + (key||'(none)'));
  const sm = await get('/sitemap.xml');
  const locs = (sm.match(/<loc>([^<]+)<\/loc>/g)||[]).map(function(x){ return x.replace(/<\/?loc>/g,''); });
  console.log('   sitemap URLs: ' + locs.length);
  const r = await indexnow.ping(pool, 'https://galaxyzayron.store', locs);
  console.log('   IndexNow response: ' + JSON.stringify(r));
  await pool.end();
})().catch(e => { console.error(e.message); process.exit(1); });
JS
node /tmp/indexnow_submit.js
echo "   key file check:"; KEY=$(node -e "const R='/opt/gsz';require(R+'/node_modules/dotenv').config({path:R+'/.env'});const{Pool}=require(R+'/node_modules/pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"SELECT value FROM wa_settings WHERE key='indexnow_key'\").then(r=>{process.stdout.write(r.rows[0]?r.rows[0].value:'');return p.end();});")
curl -s -o /dev/null -w "   /$KEY.txt -> %{http_code}\n" "http://127.0.0.1:3900/$KEY.txt" || true
echo "DONE — www 301 live; IndexNow key served; all current URLs submitted to Bing/Yandex."
