#!/usr/bin/env bash
# stepLibAdmin.sh — premium /admin/iptv-library section (DB-driven, self-aware) + phone-agent status + wiring.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
cp -f server.js "server.js.xbak.$TS"
cp -f views/admin/_shell_top.ejs "views/admin/_shell_top.ejs.xbak.$TS"
cp -f views/admin/dashboard.ejs "views/admin/dashboard.ejs.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "server.js.xbak.$TS" server.js; cp -f "views/admin/_shell_top.ejs.xbak.$TS" views/admin/_shell_top.ejs; cp -f "views/admin/dashboard.ejs.xbak.$TS" views/admin/dashboard.ejs; rm -f routes/adminIptv.js views/admin/iptv.ejs .pj.js; exit 1; }
trap restore ERR

echo "==> writing routes/adminIptv.js"
cat > routes/adminIptv.js <<'AJS'
'use strict';
/* Admin — IPTV Library monitor. Fully DB-driven + self-aware: every active IPTV product auto-appears,
   so adding a new panel needs ZERO code here. Traces counts, source/via, freshness, phone-agent health,
   and the full update history, with per-panel manual re-sync. Read-only to the engine. */
const express = require('express');
module.exports = function (pool) {
  const router = express.Router();
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  async function panels() {
    return (await pool.query(
      `SELECT p.slug AS server_key, p.name,
              l.live_count, l.vod_count, l.series_count, l.episode_count,
              l.status, l.updated_at, l.last_source, l.last_via,
              (COALESCE(l.live_count,0)+COALESCE(l.vod_count,0)+COALESCE(l.series_count,0)) AS total,
              CASE WHEN l.updated_at IS NULL THEN NULL ELSE round(EXTRACT(EPOCH FROM (now()-l.updated_at))/3600.0, 1) END AS age_h
         FROM products p JOIN categories c ON c.id=p.category_id
         LEFT JOIN iptv_library l ON l.server_key=p.slug
        WHERE c.slug='iptv' AND p.active AND NOT p.hidden
        ORDER BY total DESC NULLS LAST, p.name`)).rows;
  }
  function classify(r) {
    if (r.updated_at == null || Number(r.total) === 0) return 'never';
    if (r.age_h != null && Number(r.age_h) >= 12) return 'stale';
    if (Number(r.vod_count || 0) === 0 || Number(r.series_count || 0) === 0) return 'partial';
    return 'fresh';
  }
  async function recentLog(limit) {
    return (await pool.query(
      `SELECT server_key, source, via, live_count, vod_count, series_count, episode_count, status, note, created_at
         FROM iptv_library_log ORDER BY id DESC LIMIT $1`, [limit || 40])).rows;
  }
  async function phoneHealth() {
    const row = (await pool.query("SELECT created_at FROM iptv_library_log WHERE source='phone' ORDER BY id DESC LIMIT 1")).rows[0];
    const last = row ? row.created_at : null;
    const ageH = last ? ((Date.now() - new Date(last).getTime()) / 3600000) : null;
    const state = last == null ? 'offline' : (ageH < 6 ? 'online' : (ageH < 16 ? 'idle' : 'offline'));
    return { last, ageH, state };
  }

  router.get('/iptv-library', auth, async (req, res) => {
    try {
      const rows = await panels();
      rows.forEach(r => r.state = classify(r));
      const stat = {
        total: rows.length,
        fresh: rows.filter(r => r.state === 'fresh').length,
        attention: rows.filter(r => r.state !== 'fresh').length,
        titles: rows.reduce((n, r) => n + (+r.total || 0), 0),
        live: rows.reduce((n, r) => n + (+r.live_count || 0), 0),
        vod: rows.reduce((n, r) => n + (+r.vod_count || 0), 0),
        series: rows.reduce((n, r) => n + (+r.series_count || 0), 0),
        episodes: rows.reduce((n, r) => n + (+r.episode_count || 0), 0),
        newest: rows.reduce((a, r) => (r.updated_at && (!a || r.updated_at > a)) ? r.updated_at : a, null)
      };
      res.render('admin/iptv', { active: 'iptv', title: 'IPTV Library', panels: rows, stat, log: await recentLog(40), phone: await phoneHealth() });
    } catch (e) { res.status(500).send('iptv-library error: ' + e.message); }
  });

  router.get('/iptv-library/history.json', auth, async (req, res) => {
    try {
      const srv = String(req.query.server || '').trim();
      const r = srv
        ? (await pool.query("SELECT server_key,source,via,live_count,vod_count,series_count,episode_count,status,note,created_at FROM iptv_library_log WHERE server_key=$1 ORDER BY id DESC LIMIT 60", [srv])).rows
        : await recentLog(60);
      res.json({ ok: true, log: r, phone: await phoneHealth() });
    } catch (e) { res.status(500).json({ ok: false }); }
  });

  router.post('/iptv-library/resync', auth, express.urlencoded({ extended: true }), async (req, res) => {
    try {
      const srv = String(req.body.server || '').trim();
      if (!srv) return res.json({ ok: false, error: 'no server' });
      await pool.query("UPDATE iptv_library SET updated_at = now() - interval '2 days' WHERE server_key=$1", [srv]);
      await pool.query("INSERT INTO iptv_library_log(server_key,source,via,status,note) VALUES($1,'admin','resync','queued','manual re-sync requested')", [srv]);
      res.json({ ok: true });
    } catch (e) { res.json({ ok: false, error: e.message }); }
  });

  return router;
};
AJS
node --check routes/adminIptv.js

echo "==> writing views/admin/iptv.ejs"
cat > views/admin/iptv.ejs <<'EJS'
<%- include('_shell_top', { active:'iptv', title:'IPTV Library' }) %>
<% function fmt(n){ return Number(n||0).toLocaleString('en-US'); } %>
<% function ago(d){ if(!d) return 'never'; var s=(Date.now()-new Date(d).getTime())/1000; if(s<60) return 'just now'; if(s<3600) return Math.round(s/60)+'m ago'; if(s<86400) return Math.round(s/3600)+'h ago'; return Math.round(s/86400)+'d ago'; } %>
<style>
  .lib-phone{display:flex;align-items:center;gap:14px;background:#fff;border-radius:16px;padding:15px 18px;margin-bottom:20px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 16px 34px -26px rgba(15,24,54,.28);border-left:4px solid #16b765}
  .lib-ph-idle{border-left-color:#f5a623}
  .lib-ph-offline{border-left-color:#e5484d;background:#fff6f6}
  .lib-ph-ic{width:44px;height:44px;border-radius:12px;display:grid;place-items:center;background:#eaf8f0;color:#16b765;flex:none}
  .lib-ph-offline .lib-ph-ic{background:#fdeaea;color:#e5484d}.lib-ph-idle .lib-ph-ic{background:#fff4e2;color:#b26a00}
  .lib-ph-ic svg{width:22px;height:22px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
  .lib-ph-t{font-weight:800;font-size:14.5px}.lib-ph-s{font-size:12.5px;color:var(--muted);font-weight:600}
  .lib-ph-cmd{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
  .lib-ph-cmd code{background:#0f1830;color:#8fe3b0;padding:8px 13px;border-radius:9px;font-size:14px;font-weight:800;letter-spacing:.02em}
  .lib-pill{display:inline-flex;align-items:center;gap:5px;font-size:11px;font-weight:800;padding:3px 9px;border-radius:999px}
  .lib-fresh{background:#e7f8ee;color:#0f8a4d}.lib-stale{background:#fdeaea;color:#c0362c}.lib-partial{background:#fff4e2;color:#b26a00}.lib-never{background:#eef0f5;color:#6b7390}
  .lib-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:16px}
  @media(max-width:860px){.lib-grid{grid-template-columns:1fr}}
  .lib-card{background:#fff;border-radius:16px;padding:16px 17px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 16px 34px -26px rgba(15,24,54,.28)}
  .lib-top{display:flex;align-items:center;gap:10px;margin-bottom:12px}.lib-nm{font-weight:800;font-size:15px}.lib-sp{flex:1}
  .lib-nums{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:12px}
  .lib-n{background:#f7f8fb;border-radius:10px;padding:8px 6px;text-align:center}
  .lib-n b{display:block;font-size:16px;font-weight:800;font-family:'Schibsted Grotesk',sans-serif}
  .lib-n span{font-size:10px;text-transform:uppercase;letter-spacing:.04em;color:var(--muted);font-weight:700}
  .lib-meta{display:flex;align-items:center;gap:10px;flex-wrap:wrap;font-size:12px;color:var(--muted);font-weight:600;margin-bottom:12px}
  .lib-src{background:#eef2fb;color:#49527a;border-radius:999px;padding:2px 8px;font-size:11px;font-weight:700}
  .lib-btn{display:inline-flex;align-items:center;gap:7px;font-weight:700;font-size:13px;padding:8px 13px;border-radius:10px;border:0;cursor:pointer;background:var(--brand,#2a7bff);color:#fff;transition:.15s}
  .lib-btn:hover{filter:brightness(1.05)}.lib-btn:disabled{opacity:.6;cursor:default}
  .lib-btn svg{width:15px;height:15px;stroke:currentColor;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
  .lib-log{max-height:520px;overflow:auto}
  .lib-lrow{display:flex;align-items:center;gap:10px;padding:10px 0;border-top:1px solid var(--hair);font-size:13px}.lib-lrow:first-child{border-top:0}
  .lib-dot{width:8px;height:8px;border-radius:50%;flex:none}.lib-ok{background:#16b765}.lib-bad{background:#e5484d}.lib-q{background:#f5a623}
  .lib-lsrv{font-weight:700}.lib-lmeta{color:var(--muted);font-size:11.5px}
</style>

<div class="lib-phone lib-ph-<%= phone.state %>">
  <div class="lib-ph-ic">
    <% if(phone.state==='online'){ %><svg viewBox="0 0 24 24"><path d="M5 12.55a11 11 0 0 1 14 0"/><path d="M8.5 16.1a6 6 0 0 1 7 0"/><path d="M2 8.82a15 15 0 0 1 20 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>
    <% } else { %><svg viewBox="0 0 24 24"><path d="M12 20h.01"/><path d="M8.5 16.1a6 6 0 0 1 7 0"/><line x1="2" y1="2" x2="22" y2="22"/></svg><% } %>
  </div>
  <div style="flex:1;min-width:0">
    <div class="lib-ph-t">Phone Agent · <%= phone.state==='online'?'Online':phone.state==='idle'?'Idle':'Offline — needs a start' %></div>
    <div class="lib-ph-s"><%= phone.last ? ('Last push '+ago(phone.last)) : 'No push recorded yet' %><%= phone.ageH!=null ? (' · '+Number(phone.ageH).toFixed(1)+'h ago') : '' %></div>
  </div>
  <% if(phone.state!=='online'){ %>
  <div class="lib-ph-cmd">
    <code>gsz</code>
    <button class="lib-btn" onclick="copyCmd('gsz',this)">Copy</button>
    <button class="lib-btn" style="background:#5b6478" onclick="copyCmd(window.__full,this)">Full command</button>
  </div>
  <% } %>
</div>

<div class="dcards">
  <div class="dcard" style="--t:#2a7bff"><div class="dic"><svg viewBox="0 0 24 24"><rect x="2" y="7" width="20" height="13" rx="2"/><path d="M17 2l-5 5-5-5"/></svg></div><div class="dmeta"><div class="dlbl">Panels indexed</div><div class="dval"><%= stat.total %></div><div class="dsub"><%= stat.fresh %> fresh · <%= stat.attention %> need attention</div></div></div>
  <div class="dcard" style="--t:#16a34a"><div class="dic"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h10"/></svg></div><div class="dmeta"><div class="dlbl">Total titles</div><div class="dval"><%= fmt(stat.titles) %></div><div class="dsub"><%= fmt(stat.live) %> live · <%= fmt(stat.vod) %> VOD · <%= fmt(stat.series) %> series</div></div></div>
  <div class="dcard" style="--t:<%= stat.attention?'#b26a00':'#16a34a' %>"><div class="dic"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg></div><div class="dmeta"><div class="dlbl">Episodes · last update</div><div class="dval"><%= fmt(stat.episodes) %></div><div class="dsub<%= stat.attention?' alert':'' %>"><%= stat.newest ? ('updated '+ago(stat.newest)) : 'no data yet' %></div></div></div>
</div>

<div class="lib-grid">
<% panels.forEach(function(r){ var st=r.state; %>
  <div class="lib-card">
    <div class="lib-top"><div class="lib-nm"><%= r.name %></div><div class="lib-sp"></div><span class="lib-pill lib-<%= st %>"><%= st==='fresh'?'Fresh':st==='stale'?'Stale':st==='partial'?'Partial':'No data' %></span></div>
    <div class="lib-nums">
      <div class="lib-n"><b><%= fmt(r.live_count) %></b><span>Live</span></div>
      <div class="lib-n"><b><%= fmt(r.vod_count) %></b><span>VOD</span></div>
      <div class="lib-n"><b><%= fmt(r.series_count) %></b><span>Series</span></div>
      <div class="lib-n"><b><%= fmt(r.episode_count) %></b><span>Episodes</span></div>
    </div>
    <div class="lib-meta">
      <% if(r.last_source){ %><span class="lib-src"><%= r.last_source %><%= r.last_via?(' · '+r.last_via):'' %></span><% } %>
      <span>Updated <%= ago(r.updated_at) %><%= r.age_h!=null?(' ('+r.age_h+'h)'):'' %></span>
    </div>
    <button class="lib-btn" data-srv="<%= r.server_key %>" onclick="resync(this)"><svg viewBox="0 0 24 24"><path d="M21 2v6h-6"/><path d="M3 12a9 9 0 0 1 15-6.7L21 8"/><path d="M3 22v-6h6"/><path d="M21 12a9 9 0 0 1-15 6.7L3 16"/></svg>Re-sync</button>
  </div>
<% }); %>
</div>

<div class="dpanel" style="margin-top:20px;padding:16px 18px">
  <div class="dph" style="padding:0 0 10px"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg><b>Update history</b><span class="sp"></span><span class="dsub">auto-refreshing</span></div>
  <div class="lib-log" id="libLog">
    <% log.forEach(function(x){ var cl=x.status==='ok'?'lib-ok':(x.status==='fail'?'lib-bad':'lib-q'); var meta=x.status==='ok'?(fmt(x.live_count)+' live · '+fmt(x.vod_count)+' vod · '+fmt(x.series_count)+' series'):(x.note||x.status); %>
      <div class="lib-lrow"><span class="lib-dot <%= cl %>"></span><div style="flex:1;min-width:0"><div class="lib-lsrv"><%= x.server_key %> <span class="lib-src"><%= x.source||'' %><%= x.via?(' · '+x.via):'' %></span></div><div class="lib-lmeta"><%= meta %></div></div><div class="lib-lmeta"><%= ago(x.created_at) %></div></div>
    <% }); %>
  </div>
</div>

<script>
  window.__full = "termux-wake-lock 2>/dev/null; pkill -f gsz-iptv 2>/dev/null; [ -f ~/gsz-iptv.sh ] || cp ~/gsz-run.sh ~/gsz-iptv.sh 2>/dev/null; nohup sh ~/gsz-iptv.sh >~/gsz.log 2>&1 & echo started";
  function copyCmd(t,btn){ var o=btn.textContent; (navigator.clipboard?navigator.clipboard.writeText(t):Promise.reject()).then(function(){ btn.textContent='Copied'; setTimeout(function(){ btn.textContent=o; },1500); }).catch(function(){ btn.textContent='Copy failed'; setTimeout(function(){ btn.textContent=o; },1500); }); }
  function cliAgo(d){ if(!d) return ''; var s=(Date.now()-new Date(d).getTime())/1000; if(s<60) return 'just now'; if(s<3600) return Math.round(s/60)+'m ago'; if(s<86400) return Math.round(s/3600)+'h ago'; return Math.round(s/86400)+'d ago'; }
  function f(n){ return Number(n||0).toLocaleString('en-US'); }
  function resync(btn){ var s=btn.getAttribute('data-srv'); btn.disabled=true; btn.textContent='Queued…'; fetch('/admin/iptv-library/resync',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'server='+encodeURIComponent(s)}).then(function(r){return r.json();}).then(function(j){ btn.textContent=j.ok?'Queued':'Failed'; if(j.ok) setTimeout(refreshLog,1500); setTimeout(function(){ btn.disabled=false; btn.innerHTML='<svg viewBox=\"0 0 24 24\"><path d=\"M21 2v6h-6\"/><path d=\"M3 12a9 9 0 0 1 15-6.7L21 8\"/><path d=\"M3 22v-6h6\"/><path d=\"M21 12a9 9 0 0 1-15 6.7L3 16\"/></svg>Re-sync'; },3500); }).catch(function(){ btn.textContent='Failed'; btn.disabled=false; }); }
  function refreshLog(){ fetch('/admin/iptv-library/history.json').then(function(r){return r.json();}).then(function(j){ if(!j.ok) return; var el=document.getElementById('libLog'); el.innerHTML=j.log.map(function(x){ var cl=x.status==='ok'?'lib-ok':(x.status==='fail'?'lib-bad':'lib-q'); var meta=x.status==='ok'?(f(x.live_count)+' live · '+f(x.vod_count)+' vod · '+f(x.series_count)+' series'):(x.note||x.status); return '<div class=\"lib-lrow\"><span class=\"lib-dot '+cl+'\"></span><div style=\"flex:1;min-width:0\"><div class=\"lib-lsrv\">'+x.server_key+' <span class=\"lib-src\">'+(x.source||'')+(x.via?(' · '+x.via):'')+'</span></div><div class=\"lib-lmeta\">'+meta+'</div></div><div class=\"lib-lmeta\">'+cliAgo(x.created_at)+'</div></div>'; }).join(''); }); }
  setInterval(refreshLog,20000);
</script>

<%- include('_shell_bottom') %>
EJS

echo "==> ejs render check"
node -e "var ejs=require('/opt/gsz/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('views/admin/iptv.ejs','utf8'),{filename:'/opt/gsz/views/admin/iptv.ejs'});console.log('  ejs ok');"

echo "==> wiring: mount route + side-nav + dashboard tile"
cat > .pj.js <<'PJS'
var fs = require('fs');
function one(file, a, b) { var s = fs.readFileSync(file, 'utf8'); var n = s.split(a).length - 1; if (n !== 1) { console.log('  ' + file + ' anchor x' + n + ' :: ' + a.slice(0, 42)); process.exit(2); } fs.writeFileSync(file, s.split(a).join(b)); console.log('  ' + file + ': ok'); }
one('server.js',
`app.use('/admin', adminMaintenanceRouter);`,
`app.use('/admin', adminMaintenanceRouter);
const adminIptvRouter = require('./routes/adminIptv')(pool); app.use('/admin', adminIptvRouter);`);
one('views/admin/_shell_top.ejs',
`<a href="/admin/inventory" class="<%= on('inventory') %>">`,
`<a href="/admin/iptv-library" class="<%= on('iptv') %>"><svg viewBox="0 0 24 24"><rect x="2" y="7" width="20" height="13" rx="2"/><path d="M17 2l-5 5-5-5"/></svg>IPTV Library</a>
    <a href="/admin/inventory" class="<%= on('inventory') %>">`);
one('views/admin/dashboard.ejs',
`>Discount codes</a>`,
`>Discount codes</a>
  <a class="dact" href="/admin/iptv-library"><svg viewBox="0 0 24 24"><rect x="2" y="7" width="20" height="13" rx="2"/><path d="M17 2l-5 5-5-5"/></svg>IPTV Library</a>`);
process.exit(0);
PJS
node .pj.js
node --check server.js
rm -f .pj.js
echo "   wiring + checks ok"
trap - ERR

echo "==> restart site + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health failed — rolling back"; cp -f "server.js.xbak.$TS" server.js; cp -f "views/admin/_shell_top.ejs.xbak.$TS" views/admin/_shell_top.ejs; cp -f "views/admin/dashboard.ejs.xbak.$TS" views/admin/dashboard.ejs; rm -f routes/adminIptv.js views/admin/iptv.ejs; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
echo "DONE — /admin/iptv-library live (dcards, phone status, per-panel, history, re-sync)."
