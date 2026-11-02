#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### customers table columns ###"
PID=$(pm2 pid gsz 2>/dev/null | head -1 | tr -dc '0-9')
[ -r "/proc/$PID/environ" ] && while IFS= read -r -d '' kv; do export "$kv" 2>/dev/null || true; done < "/proc/$PID/environ"
cat > .gszm_d.js <<'JS'
(async()=>{ try{ const fs=require('fs'); const {Pool}=require('pg'); let p; try{const s=fs.readFileSync('server.js','utf8');const m=s.match(/new\s+Pool\s*\(([\s\S]*?)\)/);p=new Pool(m&&m[1].trim()?eval('('+m[1]+')'):{});}catch(e){p=new Pool();}
  const c=await p.query("SELECT column_name,data_type FROM information_schema.columns WHERE table_name='customers' ORDER BY ordinal_position");
  console.log(c.rows.map(function(r){return r.column_name+':'+r.data_type;}).join(', '));
  await p.end(); }catch(e){ console.log('ERR',e.message);} process.exit(0); })();
JS
node .gszm_d.js; rm -f .gszm_d.js
echo
echo "### admin customers route + view ###"
ls -1 views/admin | grep -iE 'custom'
grep -rnE "/customers|router.(get|post)\(.*customer|SELECT .*FROM customers|change.*password|reset.*password|UPDATE customers" routes/adminCatalog.js routes/admin.js routes/*.js 2>/dev/null | grep -viE '\.bak|\.xbak' | grep -iE 'customer' | head -30
echo
echo "### geo / country detection ###"
grep -rnE "cf-ipcountry|CF-IPCountry|ipcountry|geoCountry|detectCountry|country" lib/geo*.js lib/*.js routes/geo.js 2>/dev/null | grep -viE '\.bak|\.xbak' | grep -iE 'country|geo' | head -20
echo
echo "### any phone/number -> country logic ###"
grep -rnE "dialCode|countryCode|phoneCountry|wa.*country|\\+92|number.*country" lib/*.js routes/*.js 2>/dev/null | grep -viE '\.bak|\.xbak' | head -10
