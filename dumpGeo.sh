#!/usr/bin/env bash
# dumpGeo.sh — map the current Geo SEO engine so I can add "type a country -> all its cities"
# (country + city pages, no limit). Targeted output.
set -uo pipefail
GSZ=/opt/gsz
echo "========== A) geo files that exist (+ sizes) =========="
ls -la "$GSZ"/libsrc/geo*.js "$GSZ"/routes/geo*.js "$GSZ"/routes/adminGeo*.js "$GSZ"/views/geo*.ejs "$GSZ"/views/admin/geo*.ejs 2>/dev/null
echo "--- data + scripts ---"
ls -la "$GSZ"/data/geo_locations.json "$GSZ"/scripts/geo_*.js 2>/dev/null
echo "--- migrations ---"
ls -la "$GSZ"/migrations/*geo* 2>/dev/null

echo
echo "========== B) geo DB schema (tables/columns) =========="
cat "$GSZ"/migrations/*geo* 2>/dev/null | grep -iE "create table|column|iso|country|city|slug|location|page|unique|index|primary key" | head -50

echo
echo "========== C) geo_locations.json — shape + count =========="
node -e 'try{const a=require("'"$GSZ"'/data/geo_locations.json"); const arr=Array.isArray(a)?a:(a.locations||a.cities||Object.values(a)[0]||[]); console.log("top keys:",Array.isArray(a)?"(array)":Object.keys(a).slice(0,8).join(",")); console.log("count:",arr.length); console.log("sample:",JSON.stringify(arr.slice(0,3)));}catch(e){console.log("ERR",e.message);}'

echo
echo "========== D) how pages route + render (country vs city) =========="
echo "--- routes/geo.js: url patterns + db queries + render ---"
grep -nE "router\.(get|post)\(|res\.render\(|SELECT |slug|iso|country|city|:country|:city|param" "$GSZ/routes/geo.js" 2>/dev/null | head -40
echo
echo "--- how geo routes are MOUNTED in server.js ---"
grep -nE "geo|adminGeo" "$GSZ/server.js" 2>/dev/null | head -12

echo
echo "========== E) admin generation (how locations/pages get created today) =========="
echo "--- routes/adminGeo.js: endpoints + insert/generate ---"
grep -nE "router\.(get|post)\(|INSERT|generate|seed|bulk|publish|res\.render|res\.json" "$GSZ/routes/adminGeo.js" 2>/dev/null | head -40
echo
echo "--- scripts that seed/generate (names + first comment line) ---"
for f in "$GSZ"/scripts/geo_seed.js "$GSZ"/scripts/geo_bulk_run.js "$GSZ"/scripts/geo_locations_load.js; do [ -f "$f" ] && echo "### $f" && head -6 "$f"; done

echo
echo "DONE"
