#!/usr/bin/env bash
# gsz-stepAdminRaw : the admin IPTV Library page (routes/adminIptv.js) renders the FILTERED counts
# (live_count/vod_count/series_count), while the storefront and /library show the full RAW counts
# (raw_live/raw_vod/raw_series). That's why admin showed B1G as 18,980 live instead of 26,611.
# Fix: the panels query now selects raw with a fallback (raw>0 ? raw : filtered), aliased back to the
# same column names so the view and the totals need no change. GROUP BY extended to keep it valid.
# Safe: backup, 1-match anchor guards (applied GROUP BY first so the SELECT columns become unique),
# node --check, auto-revert on failure, then pm2 restart to reload the route.
set -e
cd /opt/gsz
F=routes/adminIptv.js
cp "$F" /opt/gsz/.gsz-adminraw.bak

cat > /tmp/gsz_adminraw_patch.js <<'PATCH'
const fs=require('fs');
const f='/opt/gsz/routes/adminIptv.js';
let s=fs.readFileSync(f,'utf8');
function rep(o,n){ const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+': '+o.slice(0,60)); process.exit(5);} s=s.replace(o,()=>n); }

// 1) GROUP BY first — add raw_* so the aliased SELECT expressions stay valid. (Doing this first also
//    makes the plain "l.live_count, l.vod_count, ..." column list below a unique match.)
rep(
"GROUP BY s.server_key, s.name, l.live_count, l.vod_count, l.series_count, l.episode_count, l.status, l.updated_at, l.last_source, l.last_via",
"GROUP BY s.server_key, s.name, l.raw_live, l.live_count, l.raw_vod, l.vod_count, l.raw_series, l.series_count, l.episode_count, l.status, l.updated_at, l.last_source, l.last_via"
);

// 2) SELECT columns -> raw with fallback, aliased back to the same names (view/totals unchanged)
rep(
"l.live_count, l.vod_count, l.series_count, l.episode_count,",
"COALESCE(NULLIF(l.raw_live,0),l.live_count) AS live_count, COALESCE(NULLIF(l.raw_vod,0),l.vod_count) AS vod_count, COALESCE(NULLIF(l.raw_series,0),l.series_count) AS series_count, l.episode_count,"
);

// 3) total -> raw with fallback
rep(
"(COALESCE(l.live_count,0)+COALESCE(l.vod_count,0)+COALESCE(l.series_count,0)) AS total,",
"(COALESCE(NULLIF(l.raw_live,0),l.live_count,0)+COALESCE(NULLIF(l.raw_vod,0),l.vod_count,0)+COALESCE(NULLIF(l.raw_series,0),l.series_count,0)) AS total,"
);

fs.writeFileSync(f,s);
console.log('PATCHED OK');
PATCH

node /tmp/gsz_adminraw_patch.js || { echo "patch failed - reverting"; cp /opt/gsz/.gsz-adminraw.bak "$F"; exit 1; }
node --check "$F" || { echo "syntax error - reverting"; cp /opt/gsz/.gsz-adminraw.bak "$F"; exit 1; }

pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
echo "DONE: admin IPTV Library now shows the full raw counts (B1G 26,611 live). Reload /admin/iptv-library."
