#!/usr/bin/env bash
# stepGeoTargeting.sh — Geo Product Targeting admin (/admin/geo/targeting):
#   * new view  views/admin/geo_targeting.ejs
#   * routes/adminGeo.js  (targeting data + save-location + apply-product)
#   * views/admin/geo.ejs (link to targeting)
#   * patches routes/geo.js so applyGeoRules reads regional_price + currency_override and
#     the card pricing shows a custom market price when one is set.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.geotgtbak.$TS"; mkdir -p "$BAKDIR"
AC="$GSZ/routes/adminGeo.js"; GE="$GSZ/views/admin/geo.ejs"; GT="$GSZ/views/admin/geo_targeting.ejs"; GJ="$GSZ/routes/geo.js"
restore(){ echo "!! failed — rolling back";
  [ -f "$BAKDIR/adminGeo.js" ] && cp -f "$BAKDIR/adminGeo.js" "$AC"
  [ -f "$BAKDIR/geo.ejs" ] && cp -f "$BAKDIR/geo.ejs" "$GE"
  [ -f "$BAKDIR/geo.js" ] && cp -f "$BAKDIR/geo.js" "$GJ"
  [ -f "$GT" ] && [ ! -f "$BAKDIR/geo_targeting.ejs" ] && rm -f "$GT"
  pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$AC" "$BAKDIR/adminGeo.js"; cp -f "$GE" "$BAKDIR/geo.ejs"; cp -f "$GJ" "$BAKDIR/geo.js"
[ -f "$GT" ] && cp -f "$GT" "$BAKDIR/geo_targeting.ejs"

echo "==> deploy admin files"
cp -f "$DEPLOY/routes/adminGeo.js"            "$AC"
cp -f "$DEPLOY/views/admin/geo.ejs"           "$GE"
cp -f "$DEPLOY/views/admin/geo_targeting.ejs" "$GT"

echo "==> patch routes/geo.js (card rules honor regional price)"
export GJ
node <<'NODE'
const fs=require('fs'); const GJ=process.env.GJ; let j=fs.readFileSync(GJ,'utf8'); let n=0;

// 1) applyGeoRules SELECT — add regional_price, currency_override
const selOld="product_id, location_id, availability, recommended, featured, special_notice FROM geo_product_rules";
const selNew="product_id, location_id, availability, recommended, featured, special_notice, regional_price, currency_override FROM geo_product_rules";
if(j.indexOf(selNew)>=0){ console.log('   SELECT already extended'); }
else { if(j.split(selOld).length-1!==1) throw new Error('applyGeoRules SELECT anchor not unique'); j=j.split(selOld).join(selNew); n++; console.log('   SELECT extended'); }

// 2) set line — carry regional price onto the product
const setOld="if (r) { p._recommended = !!r.recommended; p._featured = !!r.featured; if (r.special_notice) p._notice = r.special_notice; }";
const setNew="if (r) { p._recommended = !!r.recommended; p._featured = !!r.featured; if (r.special_notice) p._notice = r.special_notice; if (r.regional_price != null) { p._regional = r.regional_price; p._curOverride = r.currency_override || null; } }";
if(j.indexOf('p._regional = r.regional_price')>=0){ console.log('   set line already extended'); }
else { if(j.split(setOld).length-1!==1) throw new Error('applyGeoRules set anchor not unique'); j=j.split(setOld).join(setNew); n++; console.log('   set line extended'); }

// 3) card pricing loop — custom market price wins, else country-resolved price
const loopOld=
"          if (_gsz && _cc) {\n"+
"            for (const _p of products) {\n"+
"              if (Number(_p.from) > 0) { try { const _pr = await _gsz.resolve({ price_pkr: _p.from, price_usd: _p.from_usd }, _cc); if (_pr) _p._geoPrice = _pr; } catch (e) {} }\n"+
"            }\n"+
"          }";
const loopNew=
"          for (const _p of products) {\n"+
"            if (_p._regional != null && Number(_p._regional) > 0) {\n"+
"              var _sym = _p._curOverride || '';\n"+
"              var _amt = Number(_p._regional);\n"+
"              _p._geoPrice = { display: (_sym ? _sym + ' ' : '') + _amt.toLocaleString('en-US'), amount: _amt, currency: _p._curOverride || null, custom: true };\n"+
"            } else if (_gsz && _cc && Number(_p.from) > 0) {\n"+
"              try { const _pr = await _gsz.resolve({ price_pkr: _p.from, price_usd: _p.from_usd }, _cc); if (_pr) _p._geoPrice = _pr; } catch (e) {}\n"+
"            }\n"+
"          }";
if(j.indexOf('_p._regional != null && Number(_p._regional)')>=0){ console.log('   pricing loop already regional-aware'); }
else { if(j.split(loopOld).length-1!==1) throw new Error('pricing loop anchor not unique (run stepGeoPrice.sh first)'); j=j.split(loopOld).join(loopNew); n++; console.log('   pricing loop now regional-aware'); }

fs.writeFileSync(GJ,j); console.log('   routes/geo.js patched ('+n+' changes)');
NODE

echo "==> checks"
node --check "$AC"; node --check "$GJ"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");for(const f of ["'"$GT"'","'"$GE"'"]){ejs.compile(fs.readFileSync(f,"utf8"),{filename:f});}console.log("   views compile OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — open /admin/geo/targeting. Backups: $BAKDIR"
