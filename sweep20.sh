#!/usr/bin/env bash
# gsz-sweep20 : make socialcounts self-load /opt/gsz/.env before opening its DB
# pool, so the live orders count populates in-app (floor + delivered orders).
set -e
cd /opt/gsz
cp lib/socialcounts.js /opt/gsz/.gsz-s20-sc.bak

cat > /tmp/s20.js <<'JS'
const fs=require('fs'); const f='lib/socialcounts.js'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf("config({ path: '/opt/gsz/.env' })")>-1){ console.log('already has dotenv'); process.exit(0); }
const a="  if (pool !== null) return pool;";
const b="  if (pool !== null) return pool;\n  try { require('dotenv').config({ path: '/opt/gsz/.env' }); } catch(e){}";
const n=s.split(a).length-1; if(n!==1){console.error('EXPECT 1, got '+n);process.exit(3);}
fs.writeFileSync(f, s.replace(a,b)); console.log('dotenv added to getPool');
JS
node /tmp/s20.js || { echo "edit failed — reverting"; cp /opt/gsz/.gsz-s20-sc.bak lib/socialcounts.js; exit 1; }
node --check lib/socialcounts.js || { echo "syntax error — reverting"; cp /opt/gsz/.gsz-s20-sc.bak lib/socialcounts.js; exit 1; }

# test with NO explicit dotenv in the command — mimics the app process
echo "=== orders-count test (engine must self-load .env now) ==="
node -e "const s=require('./lib/socialcounts'); setTimeout(function(){ console.log(JSON.stringify(s.get({}))); process.exit(0); }, 4000);"

pm2 restart gsz
echo; echo "DONE: engine self-loads .env — live orders count should now show (reload the site twice)."
