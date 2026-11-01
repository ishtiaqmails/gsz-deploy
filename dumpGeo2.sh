#!/usr/bin/env bash
# dumpGeo2.sh — geo internals: how locations are upserted, the country JSON shape, and how
# generate() builds pages + slugs. So I can add cities + generate country/city pages correctly.
set -uo pipefail
GSZ=/opt/gsz
LB="$GSZ/libsrc"; [ -d "$LB" ] || LB="$GSZ/lib"

echo "========== A) geo_locations_load.js (FULL — the upsert columns + how it reads the JSON) =========="
cat -n "$GSZ/scripts/geo_locations_load.js" 2>/dev/null

echo
echo "========== B) one full COUNTRY object from geo_locations.json (shape) =========="
node -e 'const d=require("'"$GSZ"'/data/geo_locations.json"); const cs=d.countries||[]; var c=cs.find(function(x){return /pakistan/i.test(JSON.stringify(x.name||x.country||x.iso||""));})||cs[0]; console.log("country keys:",Object.keys(c).join(",")); console.log(JSON.stringify(c).slice(0,900));'

echo
echo "========== C) geo_admin.generate() — how pages + slugs are built, and the limit =========="
echo "FILE: $LB/geo_admin.js"
grep -nE "module.exports|function |generate|slug|category|location|limit|INSERT INTO geo_pages|SELECT .* FROM geo_locations|for ?\(|forEach|intent" "$LB/geo_admin.js" 2>/dev/null | head -45

echo
echo "========== D) slug format: country page vs city page (geo_pages rows) =========="
echo "--- sample existing slugs + their location type ---"
grep -nE "slug|country|city|region|path|buildSlug|catSlug" "$LB/geo.js" "$LB/geo_bulk.js" 2>/dev/null | head -20

echo
echo "DONE"
