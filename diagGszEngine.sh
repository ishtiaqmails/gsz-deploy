#!/usr/bin/env bash
# READ-ONLY. Find galaxyzayron's library/counts automation engine + data so zayron can read from it.
G=/opt/gsz
echo "### /opt/gsz top-level ###"; ls "$G" 2>/dev/null
echo
echo "### /opt/gsz/lib ###"; ls "$G/lib" 2>/dev/null
echo
echo "### grep: library / channels / counts / search / catalog / vod / playlist ###"
grep -rlnE "channels|library|catalog|playlist|m3u|xtream|countShows|live_channels|vod" "$G/lib" "$G/routes" "$G/server.js" 2>/dev/null | grep -viE "node_modules|\.bak" | head -20
echo
echo "### geo_content.js head ###"; sed -n '1,30p' "$G/lib/geo_content.js" 2>/dev/null
echo
echo "### ALL tables in galaxyzayron DB ###"
(cd "$G" && node -e "const d=require('./db');const pool=d.pool||d;pool.query(\"SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name\").then(r=>{console.log(r.rows.map(x=>x.table_name).join(', '));process.exit(0)}).catch(e=>{console.log('ERR',e.message);process.exit(0)})" 2>/dev/null) || echo "(db.js shape differs)"
echo
echo "### does gsz have a channels/search route or counts? ###"
grep -rnE "channels|search|counts|\{channels\}|is your channel|browse everything" "$G/routes" "$G/server.js" 2>/dev/null | grep -viE "node_modules|\.bak" | head -15
echo DONE
