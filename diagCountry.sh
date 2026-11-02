#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### is CF-IPCountry / visitor country read anywhere? ###"
grep -rnE "cf-ipcountry|CF-IPCountry|x-country|ipcountry|req.country|geoCountry|headers\[.cf" routes/*.js lib/*.js server.js 2>/dev/null | grep -viE '\.bak|\.xbak' | head
echo
echo "### how region is derived per request (for pricing) ###"
grep -rnE "function reg\(|reg\(req|region =|REGIONS|regionFrom|detectRegion" routes/checkout.js lib/*.js 2>/dev/null | grep -viE '\.bak|\.xbak' | head -15
echo
echo "### any country column on customers/orders already (besides region) ###"
PID=$(pm2 pid gsz 2>/dev/null | head -1 | tr -dc '0-9')
[ -r "/proc/$PID/environ" ] && while IFS= read -r -d '' kv; do export "$kv" 2>/dev/null || true; done < "/proc/$PID/environ"
cat > .gszm_d.js <<'JS'
(async()=>{ try{ const fs=require('fs'); const {Pool}=require('pg'); let p; try{const s=fs.readFileSync('server.js','utf8');const m=s.match(/new\s+Pool\s*\(([\s\S]*?)\)/);p=new Pool(m&&m[1].trim()?eval('('+m[1]+')'):{});}catch(e){p=new Pool();}
  const cc=await p.query("SELECT column_name FROM information_schema.columns WHERE table_name IN ('customers','orders') AND (column_name ILIKE '%country%' OR column_name ILIKE '%geo%' OR column_name='region')");
  console.log('country/geo/region cols:', cc.rows.map(function(r){return r.column_name;}).join(', ') || 'none');
  const rg=await p.query("SELECT DISTINCT region FROM orders WHERE region IS NOT NULL LIMIT 20");
  console.log('order regions in use:', rg.rows.map(function(r){return r.region;}).join(', '));
  await p.end(); }catch(e){ console.log('ERR',e.message);} process.exit(0); })();
JS
node .gszm_d.js; rm -f .gszm_d.js
