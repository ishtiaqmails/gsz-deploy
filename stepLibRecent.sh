#!/usr/bin/env bash
# stepLibRecent.sh — Phase 4: "Recently added" — content growth per panel since its previous pull (from the log).
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

// 1) adminIptv.js — recentlyAdded() helper
ed('routes/adminIptv.js',
'  async function intel() {',
`  async function recentlyAdded() {
    const rows = (await pool.query("SELECT server_key, live_count, vod_count, series_count, created_at, row_number() OVER (PARTITION BY server_key ORDER BY id DESC) AS rn FROM iptv_library_log WHERE status='ok' AND live_count IS NOT NULL")).rows.filter(r => Number(r.rn) <= 2);
    const names = {}; (await pool.query("SELECT server_key, name FROM iptv_library")).rows.forEach(x => names[x.server_key] = x.name);
    const by = {}; rows.forEach(r => { (by[r.server_key] = by[r.server_key] || []).push(r); });
    const out = [];
    Object.keys(by).forEach(k => {
      const a = by[k]; if (a.length < 2) return;
      const cur = a.find(x => Number(x.rn) === 1), prev = a.find(x => Number(x.rn) === 2);
      const dl = (cur.live_count || 0) - (prev.live_count || 0), dv = (cur.vod_count || 0) - (prev.vod_count || 0), ds = (cur.series_count || 0) - (prev.series_count || 0);
      if (dl > 0 || dv > 0 || ds > 0) out.push({ panel: k, name: names[k] || k, dl, dv, ds, at: cur.created_at });
    });
    out.sort((a, b) => new Date(b.at) - new Date(a.at));
    return out.slice(0, 20);
  }
  async function intel() {`, 'recent-fn');

// 2) adminIptv.js — pass recent to the view
ed('routes/adminIptv.js',
'phone: await phoneHealth(), intel: intelData });',
'phone: await phoneHealth(), intel: intelData, recent: await recentlyAdded() });', 'recent-render');

// 3) iptv.ejs — Recently added panel before the panels grid
var V = 'views/admin/iptv.ejs';
var s = fs.readFileSync(V, 'utf8');
function one(a, b, label) { var n = s.split(a).length - 1; if (n !== 1) { console.log('  ejs ' + label + ' x' + n); process.exit(2); } s = s.split(a).join(b); console.log('  ejs ' + label + ': ok'); }

one('<div class="lib-grid">',
`<div class="lib-search">
  <div class="lib-add-t">Recently added <span class="lib-ph-s">- new content since each panel's previous refresh</span></div>
  <div class="lib-srch-res">
    <% if(!recent || !recent.length){ %><div class="lib-ph-s">No growth recorded yet - shows up after a panel is refreshed at least twice.</div><% } %>
    <% (recent||[]).forEach(function(x){ %>
      <div class="lib-sr"><span class="lib-sr-nm"><%= x.name %></span><span class="lib-sr-p"><% if(x.dv>0){ %><span class="lib-cc">+<%= Number(x.dv).toLocaleString('en-US') %> movies</span><% } %><% if(x.ds>0){ %><span class="lib-cc">+<%= Number(x.ds).toLocaleString('en-US') %> series</span><% } %><% if(x.dl>0){ %><span class="lib-cc">+<%= Number(x.dl).toLocaleString('en-US') %> live</span><% } %> <%= ago(x.at) %></span></div>
    <% }); %>
  </div>
</div>
<div class="lib-grid">`, 'recent-panel');

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
echo "DONE — Recently added is live. The ultimate IPTV Library section is complete."
