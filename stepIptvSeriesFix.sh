#!/usr/bin/env bash
# IPTV series-count fix: when the M3U path is used, take the series list from Xtream get_series
# (the authoritative show count the player displays) instead of the unreliable M3U fold.
cd /opt/gsz
f=/opt/gsz/lib/iptv/worker.js
bak="$f.bak.$(date +%s)"
cp "$f" "$bak"
node <<'EOF'
const fs=require('fs');
const f='/opt/gsz/lib/iptv/worker.js';
const orig=fs.readFileSync(f,'utf8');
const a="  if (lib.ok && (lib.live.length + lib.vod.length + lib.series.length) > 0) return { ok: true, lib, via: 'm3u' };";
const b=[
"  if (lib.ok && (lib.live.length + lib.vod.length + lib.series.length) > 0) {",
"    // Series via M3U is unreliable (episodes-as-shows, or missing). Xtream get_series is the same",
"    // list the player counts, so use it as the authoritative series list when the panel answers.",
"    try {",
"      const [sr, sc] = await Promise.all([fetch.api(host, user, pass, 'get_series'), fetch.api(host, user, pass, 'get_series_categories')]);",
"      const rows = (sr && sr.ok && Array.isArray(sr.data)) ? sr.data : [];",
"      if (rows.length) {",
"        const cm = {}; (((sc && sc.ok && Array.isArray(sc.data)) ? sc.data : [])).forEach(c => { if (c && c.category_id != null) cm[String(c.category_id)] = c.category_name || ''; });",
"        lib.series = rows.map(r => ({ name: r.name || r.title || '', category_name: cm[String(r.category_id)] || '', cover: r.cover || '', episode_count: 0 }));",
"        const sct = {}; Object.values(cm).forEach(n => { if (n) sct[n] = n; }); lib.seriesCats = Object.assign({}, lib.seriesCats || {}, sct);",
"      }",
"    } catch (e) {}",
"    return { ok: true, lib, via: 'm3u+seriesapi' };",
"  }"
].join("\n");
const n=orig.split(a).length-1;
if(n!==1){ console.log('FAIL anchor count='+n); process.exit(1); }
fs.writeFileSync(f, orig.split(a).join(b));
console.log('patched tryCreds');
EOF
if [ $? -ne 0 ]; then echo "patch failed; restoring"; cp "$bak" "$f"; echo DONE; exit 0; fi
if node -c "$f"; then echo "worker.js syntax OK"; else echo "SYNTAX ERROR; restoring"; cp "$bak" "$f"; echo DONE; exit 0; fi
# nudge Trex + 5G to the front so this sweep re-pulls them for verification
node <<'EOF'
require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{ try{ const r=await pool.query("UPDATE iptv_library SET updated_at = now() - interval '72 hours' WHERE name ILIKE 'Trex%' OR name ILIKE '5G%'"); console.log('nudged '+r.rowCount+' panel(s) for immediate re-pull'); }catch(e){ console.log('ERR '+e.message); } process.exit(0); })();
EOF
pm2 restart gsz-iptv-worker >/dev/null 2>&1 && echo "gsz-iptv-worker restarted (sweep running)" || echo "worker restart failed"
echo "backup: $bak"
echo "Re-run dumpIptvCounts.sh in ~10-15 min: Trex series should jump to ~46k, 5G series should drop to the real show count."
echo DONE
