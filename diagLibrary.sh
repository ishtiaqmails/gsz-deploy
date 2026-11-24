#!/usr/bin/env bash
# READ-ONLY. Map the library/counts on BOTH galaxyzayron (/opt/gsz) and zayron (/opt/zayron) so we can
# make zayron read the SAME library galaxyzayron uses (same channels/movies/series + counts).
echo "============ GALAXYZAYRON (/opt/gsz) ============"
if [ -d /opt/gsz ]; then
  echo "--- gsz: library/channel files ---"
  ls /opt/gsz/lib 2>/dev/null | grep -iE "chan|lib|catalog|search|content" || echo "(no lib match)"
  echo "--- gsz: channel/library tables (its DB) ---"
  (cd /opt/gsz && node -e "const{pool}=require('./db');pool.query(\"SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%chan%' OR table_name ILIKE '%lib%' OR table_name ILIKE '%catalog%' OR table_name ILIKE '%content%' OR table_name ILIKE '%stream%')\").then(r=>{console.log(r.rows.map(x=>x.table_name).join(', ')||'(none)');process.exit(0)}).catch(e=>{console.log('ERR',e.message);process.exit(0)})" 2>/dev/null) || echo "(gsz db not reachable this way)"
  echo "--- gsz: how it stores counts per server ---"
  grep -rnE "channels|movies|series|chan_count|counts" /opt/gsz/lib/*.js 2>/dev/null | grep -viE "\.bak" | head -8
else echo "(/opt/gsz not found)"; fi
echo
echo "============ ZAYRON (/opt/zayron) ============"
echo "--- zayron: lib/channels exports ---"
grep -nE "module.exports|async function|function " /opt/zayron/lib/channels.js 2>/dev/null | head -20
echo "--- zayron: channel tables (its DB) ---"
(cd /opt/zayron && node -e "const{pool}=require('./db');pool.query(\"SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%chan%' OR table_name ILIKE '%lib%' OR table_name ILIKE '%catalog%' OR table_name ILIKE '%content%' OR table_name ILIKE '%stream%')\").then(r=>{console.log(r.rows.map(x=>x.table_name).join(', ')||'(none)');process.exit(0)}).catch(e=>{console.log('ERR',e.message);process.exit(0)})")
echo "--- are gsz + zayron the SAME database? (db configs) ---"
echo "zayron db url tail:"; grep -oE "DATABASE_URL=.*" /opt/zayron/.env 2>/dev/null | sed 's/:[^:@]*@/:***@/' | tail -c 60
echo "gsz db url tail:  "; grep -oE "DATABASE_URL=.*" /opt/gsz/.env 2>/dev/null | sed 's/:[^:@]*@/:***@/' | tail -c 60
echo DONE
