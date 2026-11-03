#!/usr/bin/env bash
# stepLibIntel.sh — Phase 3: audience intelligence (rank IPTVs by country; per-panel top countries).
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
A=routes/adminIptv.js; V=views/admin/iptv.ejs
cp -f "$A" "$A.xbak.$TS"; cp -f "$V" "$V.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$A.xbak.$TS" "$A"; cp -f "$V.xbak.$TS" "$V"; rm -f .pj.js; exit 1; }
trap restore ERR

cat > .pj.js <<'PJS'
var fs = require('fs');
function ed(file, a, b, label) { var s = fs.readFileSync(file, 'utf8'); var n = s.split(a).length - 1; if (n !== 1) { console.log('  ' + label + ' x' + n); process.exit(2); } fs.writeFileSync(file, s.split(a).join(b)); console.log('  ' + label + ': ok'); }

// 1) adminIptv.js — intel() helper
ed('routes/adminIptv.js',
'  async function phoneHealth() {',
`  async function intel() {
    const rows = (await pool.query("SELECT server_key, name, categories FROM iptv_library WHERE categories IS NOT NULL AND status='ok'")).rows;
    const panelCountries = {}, countryTotals = {}, names = {};
    for (const r of rows) {
      names[r.server_key] = r.name;
      let c; try { c = typeof r.categories === 'string' ? JSON.parse(r.categories) : r.categories; } catch (e) { continue; }
      const acc = {};
      ['live', 'vod', 'series'].forEach(t => { const co = (c[t] && c[t].countries) || {}; Object.keys(co).forEach(k => { acc[k] = (acc[k] || 0) + (Number(co[k]) || 0); }); });
      panelCountries[r.server_key] = acc;
      Object.keys(acc).forEach(k => { countryTotals[k] = (countryTotals[k] || 0) + acc[k]; });
    }
    return { panelCountries, countryTotals, names };
  }
  async function phoneHealth() {`, 'intel-fn');

// 2) adminIptv.js — compute intel, attach top countries, pass to view
ed('routes/adminIptv.js',
"      res.render('admin/iptv', { active: 'iptv', title: 'IPTV Library', panels: rows, stat, log: await recentLog(40), phone: await phoneHealth() });",
`      const intelData = await intel();
      rows.forEach(r => { const pc = intelData.panelCountries[r.server_key] || {}; r.topCountries = Object.keys(pc).map(k => ({ c: k, n: pc[k] })).sort((a, b) => b.n - a.n).slice(0, 3); });
      res.render('admin/iptv', { active: 'iptv', title: 'IPTV Library', panels: rows, stat, log: await recentLog(40), phone: await phoneHealth(), intel: intelData });`, 'intel-render');

// 3) iptv.ejs — CSS for chips
var V = 'views/admin/iptv.ejs';
var s = fs.readFileSync(V, 'utf8');
function one(a, b, label) { var n = s.split(a).length - 1; if (n !== 1) { console.log('  ejs ' + label + ' x' + n); process.exit(2); } s = s.split(a).join(b); console.log('  ejs ' + label + ': ok'); }

one('  .lib-sr-p{font-size:11.5px;color:var(--muted);font-weight:600;flex:none}',
`  .lib-sr-p{font-size:11.5px;color:var(--muted);font-weight:600;flex:none}
  .lib-cc{display:inline-block;font-size:10.5px;font-weight:700;color:#5a6a8a;background:#f0f3f9;border-radius:999px;padding:1px 7px;margin:1px 3px 1px 0}`, 'css');

// 4) iptv.ejs — intelligence panel before the panels grid
one('<div class="lib-grid">',
`<div class="lib-search">
  <div class="lib-add-t">Audience intelligence <span class="lib-ph-s">- which IPTV is strongest for a country</span></div>
  <div class="lib-srch-row" style="grid-template-columns:1fr">
    <select id="intelCountry" onchange="rankIntel()"><option value="">Pick a country...</option></select>
  </div>
  <div id="intelRank" class="lib-srch-res"></div>
</div>
<div class="lib-grid">`, 'intel-panel');

// 5) iptv.ejs — per-panel top-country chips in the card meta
one(`      <span>Updated <%= ago(r.updated_at) %><%= r.age_h!=null?(' ('+r.age_h+'h)'):'' %></span>
    </div>`,
`      <span>Updated <%= ago(r.updated_at) %><%= r.age_h!=null?(' ('+r.age_h+'h)'):'' %></span>
    </div>
    <% if(r.topCountries && r.topCountries.length){ %><div style="margin-bottom:12px"><% r.topCountries.forEach(function(tc){ %><span class="lib-cc"><%= tc.c %> <%= Number(tc.n).toLocaleString('en-US') %></span><% }); %></div><% } %>`, 'chips');

// 6) iptv.ejs — embed intel JSON + populate picker + rankIntel
one('  window.__full = "termux-wake-lock 2>/dev/null;',
`  window.__intel = <%- JSON.stringify(intel) %>;
  window.__full = "termux-wake-lock 2>/dev/null;`, 'embed');

one('  setInterval(refreshLog,20000);',
`  (function(){ var sel=document.getElementById('intelCountry'); if(!sel||!window.__intel) return; var ct=window.__intel.countryTotals||{}; var ks=Object.keys(ct).sort(function(a,b){return ct[b]-ct[a];}); for(var i=0;i<ks.length;i++){ var o=document.createElement('option'); o.value=ks[i]; o.textContent=ks[i]+' ('+Number(ct[ks[i]]).toLocaleString('en-US')+')'; sel.appendChild(o); } })();
  function rankIntel(){ var c=document.getElementById('intelCountry').value; var box=document.getElementById('intelRank'); if(!c){ box.innerHTML=''; return; } var pc=window.__intel.panelCountries||{}; var nm=window.__intel.names||{}; var rows=[]; Object.keys(pc).forEach(function(k){ var n=(pc[k]&&pc[k][c])||0; if(n>0) rows.push({p:k,n:n}); }); rows.sort(function(a,b){return b.n-a.n;}); if(!rows.length){ box.innerHTML='<div class="lib-ph-s">No panel has '+esc(c)+' content.</div>'; return; } box.innerHTML='<div class="lib-ph-s">Best IPTVs for '+esc(c)+'</div>'+rows.map(function(x,i){ return '<div class="lib-sr"><span class="lib-sr-badge">#'+(i+1)+'</span><span class="lib-sr-nm">'+esc(nm[x.p]||x.p)+'</span><span class="lib-sr-p">'+Number(x.n).toLocaleString('en-US')+' items</span></div>'; }).join(''); }
  setInterval(refreshLog,20000);`, 'js');

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
echo "DONE — audience intelligence live (rank IPTVs by country + per-panel top countries)."
