#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### A) disk render marker in checkout_model.ejs (expect 1): ###"
grep -c "String.fromCharCode(10)" views/partials/checkout_model.ejs
echo "### B) endpoint map has extra_value (expect a line): ###"
grep -n "extra_value:m.extra_value" routes/checkout.js
echo "### C) which live views include checkout_model: ###"
grep -rlnE "checkout_model" views/ 2>/dev/null | grep -viE '\.bak|\.xbak'
echo "### D) data path — key => extra_value the endpoint would emit: ###"
PID=$(pm2 pid gsz 2>/dev/null | head -1 | tr -dc '0-9')
[ -r "/proc/$PID/environ" ] && while IFS= read -r -d '' kv; do export "$kv" 2>/dev/null || true; done < "/proc/$PID/environ"
cat > .gszm_d.js <<'JS'
(async()=>{ try{
  const bot=require('./lib/botapi'); const fs=require('fs'); const {Pool}=require('pg');
  let pool; try{ const s=fs.readFileSync('server.js','utf8'); const m=s.match(/new\s+Pool\s*\(([\s\S]*?)\)/); pool=new Pool(m&&m[1].trim()?eval('('+m[1]+')'):{}); }catch(e){ pool=new Pool(); }
  const accts=bot.configured()?(await bot.getPayAccounts()):[];
  const ex={}; (await pool.query('SELECT key,extra_label,extra_value FROM payment_logos')).rows.forEach(function(r){ ex[r.key]=r; });
  console.log(JSON.stringify((accts||[]).map(function(a){ return { key:a.key, ev:(ex[a.key]&&ex[a.key].extra_value)||'' }; })));
  await pool.end();
}catch(e){ console.log('ERR', e.message); } process.exit(0); })();
JS
node .gszm_d.js; rm -f .gszm_d.js
echo "### E) does the SERVER (direct, no Cloudflare) emit the new render on the product page? ###"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
PAGE=$(grep -rlnE "checkout_model" views/ 2>/dev/null | grep -viE '\.bak|\.xbak' | head -1)
echo "modal lives in: $PAGE"
