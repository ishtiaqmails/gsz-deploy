#!/usr/bin/env bash
# Feature A: Self-update control. One wa_settings key 'iptv_refresh_hours' drives
# worker.js + routes/iptv.js staleness, plus a clean admin control in the IPTV Library.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
ts=$(date +%s)
FILES="lib/iptv/worker.js routes/iptv.js routes/adminIptv.js views/admin/iptv.ejs"
for f in $FILES; do cp "$f" "$f.bak.$ts"; done
restore(){ echo "ROLLING BACK"; for f in $FILES; do cp "$f.bak.$ts" "$f"; done; }

node <<'NODE'
const fs=require('fs');
function P(file,pairs){ let s=fs.readFileSync(file,'utf8'); for(const [a,b] of pairs){ const n=s.split(a).length-1; if(n!==1){ console.log('FAIL anchor x'+n+' ['+file+']: '+JSON.stringify(a.slice(0,70))); process.exit(1);} s=s.split(a).join(b);} fs.writeFileSync(file,s); console.log('patched '+file); }

P('lib/iptv/worker.js',[[
`const cutoff = Date.now() - REFRESH_HOURS * 3600 * 1000;`,
`let _rh = REFRESH_HOURS; try { const _s=(await pool.query("SELECT value FROM wa_settings WHERE key='iptv_refresh_hours'")).rows[0]; const _n=_s?parseFloat(_s.value):0; if(_n>0&&_n<=240) _rh=_n; } catch(e){}
  const cutoff = Date.now() - _rh * 3600 * 1000;`
]]);

P('routes/iptv.js',[[
`const cutoff = Date.now() - REFRESH_HOURS * 3600 * 1000;`,
`let _rh = REFRESH_HOURS; try { const _s=(await pool.query("SELECT value FROM wa_settings WHERE key='iptv_refresh_hours'")).rows[0]; const _n=_s?parseFloat(_s.value):0; if(_n>0&&_n<=240) _rh=_n; } catch(e){}
      const cutoff = Date.now() - _rh * 3600 * 1000;`
]]);

P('routes/adminIptv.js',[
[`  function classify(r) {`,
`  let RH = 12;
  async function getRefreshHours(){ try { const s=(await pool.query("SELECT value FROM wa_settings WHERE key='iptv_refresh_hours'")).rows[0]; const n=s?parseFloat(s.value):0; if(n>0&&n<=240) return n; } catch(e){} return 12; }
  function classify(r) {`],
[`Number(r.age_h) >= 12`,`Number(r.age_h) >= RH`],
[`const rows = await panels();`,`RH = await getRefreshHours();
      const rows = await panels();`],
[`intel: intelData, recent: await recentlyAdded() });`,`intel: intelData, recent: await recentlyAdded(), refreshHours: RH });`],
[`  router.post('/iptv-library/add-source', auth, express.urlencoded({ extended: true }), async (req, res) => {`,
`  router.post('/iptv-library/refresh', auth, express.urlencoded({ extended: true }), async (req, res) => {
    try {
      let h = parseFloat(req.body.hours); if (!(h > 0)) h = 12; if (h < 1) h = 1; if (h > 240) h = 240; h = Math.round(h * 10) / 10;
      await pool.query("INSERT INTO wa_settings(key,value) VALUES('iptv_refresh_hours',$1) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value", [String(h)]);
      RH = h;
      res.json({ ok: true, hours: h });
    } catch (e) { res.json({ ok: false, error: e.message }); }
  });

  router.post('/iptv-library/add-source', auth, express.urlencoded({ extended: true }), async (req, res) => {`]
]);

P('views/admin/iptv.ejs',[
[`<div class="lib-add">
  <div class="lib-add-t">Add any IPTV `,
`<div class="lib-add" style="display:flex;align-items:center;justify-content:space-between;gap:14px;flex-wrap:wrap">
  <div style="min-width:220px">
    <div class="lib-add-t" style="margin-bottom:3px">Auto-update libraries</div>
    <div class="lib-ph-s">Every IPTV re-pulls its full library on its own. Set how often.</div>
  </div>
  <div style="display:flex;align-items:center;gap:9px;flex-wrap:wrap">
    <span class="lib-ph-s">Every</span>
    <input id="rhHours" type="number" min="1" max="240" step="1" value="<%= (typeof refreshHours!=='undefined'?refreshHours:12) %>" style="width:78px;padding:10px 12px;border:1px solid var(--hair);border-radius:10px;font-size:14px;text-align:center">
    <span class="lib-ph-s">hours</span>
    <button class="lib-btn" id="rhBtn" onclick="saveRefresh()">Save</button>
    <span class="lib-ph-s" id="rhMsg" style="min-width:70px"></span>
  </div>
</div>
<div class="lib-add">
  <div class="lib-add-t">Add any IPTV `],
[`  setInterval(refreshLog,20000);`,
`  function saveRefresh(){ var h=parseFloat(document.getElementById('rhHours').value); var msg=document.getElementById('rhMsg'); var btn=document.getElementById('rhBtn'); if(!(h>0)){ msg.textContent='Enter a number'; return; } btn.disabled=true; btn.textContent='Saving...'; fetch('/admin/iptv-library/refresh',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'hours='+encodeURIComponent(h)}).then(function(r){return r.json();}).then(function(j){ btn.disabled=false; btn.textContent='Save'; if(j.ok){ document.getElementById('rhHours').value=j.hours; msg.textContent='Saved - every '+j.hours+'h'; setTimeout(function(){ msg.textContent=''; },2600); } else { msg.textContent='Error: '+(j.error||'failed'); } }).catch(function(){ btn.disabled=false; btn.textContent='Save'; msg.textContent='Request failed'; }); }
  setInterval(refreshLog,20000);`]
]);
NODE
if [ $? -ne 0 ]; then restore; exit 1; fi

echo "== JS syntax =="
node -c lib/iptv/worker.js && node -c routes/iptv.js && node -c routes/adminIptv.js && echo "JS OK" || { restore; exit 1; }

echo "== EJS syntax =="
node -e "const ejs=require('/opt/gsz/node_modules/ejs');const fs=require('fs');try{ejs.compile(fs.readFileSync('views/admin/iptv.ejs','utf8'),{filename:'views/admin/iptv.ejs',includer:()=>({template:''})});console.log('EJS OK');}catch(e){console.log('EJS FAIL',e.message);process.exit(2);}" || { restore; exit 1; }

echo "== seed default (12h) if unset =="
node -e "require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});const{Pool}=require('/opt/gsz/node_modules/pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(\"INSERT INTO wa_settings(key,value) VALUES('iptv_refresh_hours','12') ON CONFLICT (key) DO NOTHING\").then(()=>{console.log('seed ok');return p.end();}).catch(e=>{console.log('seed err',e.message);return p.end();})"

echo "== restart =="
pm2 restart gsz gsz-iptv-worker --update-env
sleep 2
pm2 list | grep -iE "gsz|iptv"
echo DONE
