#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### review-related DB tables + columns ###"
PID=$(pm2 pid gsz 2>/dev/null | head -1 | tr -dc '0-9')
[ -r "/proc/$PID/environ" ] && while IFS= read -r -d '' kv; do export "$kv" 2>/dev/null || true; done < "/proc/$PID/environ"
cat > .gszm_d.js <<'JS'
(async()=>{ try{ const fs=require('fs'); const {Pool}=require('pg'); let p; try{const s=fs.readFileSync('server.js','utf8');const m=s.match(/new\s+Pool\s*\(([\s\S]*?)\)/);p=new Pool(m&&m[1].trim()?eval('('+m[1]+')'):{});}catch(e){p=new Pool();}
  const t=await p.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%review%' OR table_name ILIKE '%rating%')");
  if(!t.rows.length){ console.log('no review/rating tables'); }
  for(const row of t.rows){ const c=await p.query("SELECT column_name,data_type FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position",[row.table_name]); const n=await p.query('SELECT count(*)::int c FROM '+row.table_name); console.log('TABLE '+row.table_name+' ('+n.rows[0].c+' rows): '+c.rows.map(function(r){return r.column_name;}).join(', ')); }
  await p.end(); }catch(e){ console.log('ERR',e.message);} process.exit(0); })();
JS
node .gszm_d.js; rm -f .gszm_d.js
echo
echo "### review routes (files + handlers) ###"
grep -rlnE "review|rating" routes/ 2>/dev/null | grep -viE '\.bak|\.xbak'
grep -rnE "/review|reviews|rating|stars|approve.*review|review.*approve" routes/*.js 2>/dev/null | grep -viE '\.bak|\.xbak' | head -25
echo
echo "### review views / product-page review section ###"
grep -rlnE "review|rating|stars|Verified-purchase" views/ 2>/dev/null | grep -viE '\.bak|\.xbak'
grep -rnE "review|Write a review|Verified-purchase|data-rating|star" views/product.ejs views/partials/*.ejs views/index.ejs views/home.ejs 2>/dev/null | grep -viE '\.bak|\.xbak' | head -25
