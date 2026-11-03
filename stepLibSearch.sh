#!/usr/bin/env bash
# stepLibSearch.sh — Phase 2: master search across all IPTV libraries (+ per-panel / per-type filter).
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
A=routes/adminIptv.js; V=views/admin/iptv.ejs
cp -f "$A" "$A.xbak.$TS"; cp -f "$V" "$V.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$A.xbak.$TS" "$A"; cp -f "$V.xbak.$TS" "$V"; rm -f .pj.js; exit 1; }
trap restore ERR

echo "==> adminIptv.js: zlib require + searchAll + search route"
cat > .pj.js <<'PJS'
var fs = require('fs');
function edit(file, a, b, label) { var s = fs.readFileSync(file, 'utf8'); var n = s.split(a).length - 1; if (n !== 1) { console.log('  ' + file + ' ' + label + ' x' + n); process.exit(2); } fs.writeFileSync(file, s.split(a).join(b)); console.log('  ' + label + ': ok'); }

edit('routes/adminIptv.js',
"const pull = require('../lib/iptv/pull');",
`const pull = require('../lib/iptv/pull');
const zlib = require('zlib');`, 'require-zlib');

edit('routes/adminIptv.js',
'  return router;',
`  async function searchAll(q, type, panel) {
    const ql = String(q || '').toLowerCase().trim();
    if (ql.length < 2) return { items: [], total: 0 };
    let sql = "SELECT server_key, name, items FROM iptv_library WHERE items IS NOT NULL AND status='ok'";
    const args = [];
    if (panel) { sql += " AND server_key=$1"; args.push(panel); }
    const rows = (await pool.query(sql, args)).rows;
    const types = (type === 'vod' || type === 'series' || type === 'live') ? [type] : ['vod', 'series', 'live'];
    const out = []; const LIMIT = 300;
    for (const r of rows) {
      let data; try { data = JSON.parse(zlib.gunzipSync(r.items).toString()); } catch (e) { continue; }
      for (const t of types) {
        const arr = data[t] || [];
        for (let i = 0; i < arr.length; i++) {
          const it = arr[i];
          if (String(it[0] || '').toLowerCase().indexOf(ql) >= 0) {
            out.push({ panel: r.server_key, pname: r.name, type: t, name: it[0], category: it[2] || '', country: (it.length >= 7 ? (it[3] || '') : '') });
            if (out.length >= LIMIT) break;
          }
        }
        if (out.length >= LIMIT) break;
      }
      data = null;
      if (out.length >= LIMIT) break;
    }
    return { items: out, total: out.length, capped: out.length >= LIMIT };
  }
  router.get('/iptv-library/search.json', auth, async (req, res) => {
    try {
      const r = await searchAll(req.query.q, req.query.type, String(req.query.panel || '').trim());
      res.json({ ok: true, items: r.items, total: r.total, capped: !!r.capped });
    } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
  });

  return router;`, 'search-route');

var V = 'views/admin/iptv.ejs';
var s = fs.readFileSync(V, 'utf8');
function one(a, b, label) { var n = s.split(a).length - 1; if (n !== 1) { console.log('  ejs ' + label + ' x' + n); process.exit(2); } s = s.split(a).join(b); console.log('  ejs ' + label + ': ok'); }

one('  @media(max-width:620px){.lib-add-grid,.lib-add-grid.x3{grid-template-columns:1fr}}',
`  @media(max-width:620px){.lib-add-grid,.lib-add-grid.x3{grid-template-columns:1fr}}
  .lib-search{background:#fff;border-radius:16px;padding:16px 18px;margin-bottom:20px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 16px 34px -26px rgba(15,24,54,.28)}
  .lib-srch-row{display:grid;grid-template-columns:1fr auto auto auto;gap:10px}
  .lib-srch-row input,.lib-srch-row select{margin:0;padding:10px 12px;border:1px solid var(--hair);border-radius:10px;font-size:14px}
  @media(max-width:720px){.lib-srch-row{grid-template-columns:1fr 1fr}}
  .lib-srch-res{margin-top:12px;max-height:440px;overflow:auto}
  .lib-sr{display:flex;align-items:center;gap:10px;padding:8px 0;border-top:1px solid var(--hair);font-size:13px}
  .lib-sr:first-child{border-top:0}
  .lib-sr-nm{font-weight:600;flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .lib-sr-badge{font-size:10px;font-weight:800;text-transform:uppercase;padding:2px 7px;border-radius:999px;background:#eef2fb;color:#49527a;flex:none}
  .lib-sr-p{font-size:11.5px;color:var(--muted);font-weight:600;flex:none}`, 'css');

one('<div class="dcards">',
`<div class="lib-search">
  <div class="lib-srch-row">
    <input id="srchQ" placeholder="Search movies, series or channels across all your IPTVs..." onkeydown="if(event.key==='Enter'){doSearch();}">
    <select id="srchType"><option value="all">All types</option><option value="vod">Movies</option><option value="series">Series</option><option value="live">Live TV</option></select>
    <select id="srchPanel"><option value="">All IPTVs</option><% panels.forEach(function(p){ %><option value="<%= p.server_key %>"><%= p.name %></option><% }); %></select>
    <button class="lib-btn" onclick="doSearch()">Search</button>
  </div>
  <div id="srchResults" class="lib-srch-res"></div>
</div>
<div class="dcards">`, 'searchbox');

one('  setInterval(refreshLog,20000);',
`  function esc(x){ return String(x||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
  function doSearch(){ var q=document.getElementById('srchQ').value.trim(); var type=document.getElementById('srchType').value; var panel=document.getElementById('srchPanel').value; var box=document.getElementById('srchResults'); if(q.length<2){ box.innerHTML='<div class="lib-ph-s">Type at least 2 characters.</div>'; return; } box.innerHTML='<div class="lib-ph-s">Searching across your libraries...</div>'; fetch('/admin/iptv-library/search.json?q='+encodeURIComponent(q)+'&type='+encodeURIComponent(type)+'&panel='+encodeURIComponent(panel)).then(function(r){return r.json();}).then(function(j){ if(!j.ok){ box.innerHTML='<div class="lib-ph-s">Error: '+(j.error||'failed')+'</div>'; return; } if(!j.items.length){ box.innerHTML='<div class="lib-ph-s">No matches found.</div>'; return; } var tn={vod:'Movie',series:'Series',live:'Live'}; box.innerHTML='<div class="lib-ph-s">'+j.total+(j.capped?'+':'')+' matches</div>'+j.items.map(function(x){ return '<div class="lib-sr"><span class="lib-sr-badge">'+(tn[x.type]||x.type)+'</span><span class="lib-sr-nm">'+esc(x.name)+'</span><span class="lib-sr-p">'+esc(x.pname)+(x.country?(' - '+esc(x.country)):'')+'</span></div>'; }).join(''); }).catch(function(){ box.innerHTML='<div class="lib-ph-s">Search failed</div>'; }); }
  setInterval(refreshLog,20000);`, 'searchjs');

fs.writeFileSync(V, s);
process.exit(0);
PJS
node .pj.js
node --check routes/adminIptv.js
node -e "var ejs=require('/opt/gsz/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('views/admin/iptv.ejs','utf8'),{filename:'/opt/gsz/views/admin/iptv.ejs'});console.log('  ejs ok');"
rm -f .pj.js
echo "   checks passed"
trap - ERR

echo "==> restart site + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health failed — rolling back"; cp -f "$A.xbak.$TS" "$A"; cp -f "$V.xbak.$TS" "$V"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
echo "DONE — master search is live (search any content across all IPTVs, filter by type or panel)."
