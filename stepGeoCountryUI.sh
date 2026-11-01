#!/usr/bin/env bash
# stepGeoCountryUI.sh — add a "Generate a whole country" box to /admin/geo.
#   routes/adminGeo.js : + POST /geo/country -> runs scripts/geo_country.js in the background
#   views/admin/geo.ejs: + the country input (name, categories, "publish live now")
# Background spawn => no HTTP timeout even for huge countries. Reuses the tested generator.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.geouibak.$TS"; mkdir -p "$BAKDIR"
AC="$GSZ/routes/adminGeo.js"; GV="$GSZ/views/admin/geo.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/adminGeo.js" ] && cp -f "$BAKDIR/adminGeo.js" "$AC"; [ -f "$BAKDIR/geo.ejs" ] && cp -f "$BAKDIR/geo.ejs" "$GV"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$AC" "$BAKDIR/adminGeo.js"; cp -f "$GV" "$BAKDIR/geo.ejs"

echo "==> patch adminGeo.js + geo.ejs"
export AC GV
node <<'NODE'
const fs=require('fs');
const AC=process.env.AC, GV=process.env.GV;

let a=fs.readFileSync(AC,'utf8');
if(a.indexOf("/geo/country")>=0){ console.log('   adminGeo: already has /geo/country'); }
else {
  const anchor="router.post('/geo/generate', auth, urlenc, async (req, res) => {";
  if(a.split(anchor).length-1!==1) throw new Error('adminGeo anchor not unique/found');
  const route=`router.post('/geo/country', auth, urlenc, async (req, res) => {
    try {
      const country = String(req.body.country || '').trim();
      const cats = (String(req.body.category || 'iptv').trim()) || 'iptv';
      if (!country) return res.redirect('/admin/geo?err=' + enc('Enter a country name'));
      const cp = require('child_process'); const fs = require('fs');
      const GSZ = path.join(__dirname, '..');
      const live = String(req.body.publish || '') === '1';
      const args = [path.join(GSZ, 'scripts', 'geo_country.js'), country, cats]; if (!live) args.push('--draft');
      let out = 'ignore'; try { out = fs.openSync(path.join(GSZ, '.geo_country.log'), 'a'); } catch (e) {}
      const child = cp.spawn(process.execPath, args, { cwd: GSZ, detached: true, stdio: ['ignore', out, out], env: process.env });
      child.unref();
      res.redirect('/admin/geo?ok=' + enc('Started ' + (live ? 'generating + publishing' : 'staging drafts') + ' for all cities of "' + country + '" (' + cats + '). Refresh in a few seconds to watch pages appear.'));
    } catch (e) { res.redirect('/admin/geo?err=' + enc('Country generate failed: ' + e.message)); }
  });

  `;
  a=a.split(anchor).join(route+anchor);
  fs.writeFileSync(AC,a); console.log('   adminGeo: POST /geo/country added');
}

let g=fs.readFileSync(GV,'utf8');
if(g.indexOf("/admin/geo/country")>=0){ console.log('   geo.ejs: already has the country box'); }
else {
  const ganchor=`<% if (typeof err!=='undefined' && err) { %><div class="flash" style="background:#fdecea;color:#b4231b;border-color:#f6c9c4"><%= err %></div><% } %>`;
  if(g.split(ganchor).length-1!==1) throw new Error('geo.ejs anchor not unique/found');
  const card=`

<div class="card" style="border:1.5px solid #cfe0ff;background:linear-gradient(180deg,#f7fbff,#ffffff)">
  <h2 style="margin:0 0 4px">Generate a whole country</h2>
  <p class="hint" style="margin:0 0 12px">Type any country name — the engine pulls <b>every city</b> and builds the country page plus a page for each city. No limits.</p>
  <form method="post" action="/admin/geo/country" style="display:flex;gap:10px;flex-wrap:wrap;align-items:flex-end">
    <div style="flex:1 1 200px"><label class="fld">Country</label><input type="text" name="country" placeholder="Pakistan · United Kingdom · UAE · PK" required></div>
    <div style="flex:0 1 150px"><label class="fld">Categories</label><input type="text" name="category" value="iptv" placeholder="iptv · all · iptv,vpns"></div>
    <label style="display:flex;align-items:center;gap:7px;font-size:13px;font-weight:600;white-space:nowrap;padding-bottom:10px"><input type="checkbox" name="publish" value="1" style="width:16px;height:16px"> Publish live now</label>
    <button class="btn btn-p" type="submit">Generate country</button>
  </form>
  <p class="hint" style="margin:10px 0 0">Leave <b>Publish live now</b> off to stage drafts first (recommended), review below, then publish. Large countries keep building in the background — refresh to watch the count grow.</p>
</div>`;
  g=g.split(ganchor).join(ganchor+card);
  fs.writeFileSync(GV,g); console.log('   geo.ejs: country box added');
}
NODE

echo "==> checks"
node --check "$AC"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$GV"'","utf8"),{filename:"'"$GV"'"});console.log("   geo.ejs compiles OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — open /admin/geo; the 'Generate a whole country' box is at the top. Backups: $BAKDIR"
