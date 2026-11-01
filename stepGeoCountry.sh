#!/usr/bin/env bash
# stepGeoCountry.sh — install the offline world-cities dataset + the country generator.
# Adds TWO new files + one npm package. Touches no existing file and does NOT restart the
# site, so the live store is completely unaffected. The generator is run from the terminal.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy

echo "==> install dataset (country-state-city) into $GSZ"
cd "$GSZ"
if npm install country-state-city --no-audit --no-fund --save >/dev/null 2>&1; then echo "   installed"; else echo "   npm install FAILED"; exit 1; fi

echo "==> deploy generator files"
mkdir -p "$GSZ/lib" "$GSZ/scripts"
cp -f "$DEPLOY/lib/geo_world.js" "$GSZ/lib/geo_world.js"
cp -f "$DEPLOY/scripts/geo_country.js" "$GSZ/scripts/geo_country.js"

echo "==> checks"
node --check "$GSZ/lib/geo_world.js"
node --check "$GSZ/scripts/geo_country.js"
node -e 'const w=require("'"$GSZ"'/lib/geo_world.js"); if(!w.available()) throw new Error("dataset not loading"); var c=w.resolveCountry("Pakistan"); console.log("   ok: "+c.name+" resolves, "+w.citiesOf(c.iso).length+" cities available");'

echo
echo "DONE — live site untouched (no restart; the generator is a terminal command)."
echo
echo "FIRST, preview without publishing (stages drafts, nothing goes live):"
echo "   cd /opt/gsz && node scripts/geo_country.js \"Pakistan\" iptv --draft"
echo "   -> then check /admin/geo to see the staged country + city pages."
echo
echo "When happy, publish live (drop --draft):"
echo "   cd /opt/gsz && node scripts/geo_country.js \"Pakistan\" iptv"
echo
echo "Any country, any categories:"
echo "   node scripts/geo_country.js \"United Kingdom\"          # all categories"
echo "   node scripts/geo_country.js \"UAE\" iptv,vpn            # chosen categories"
