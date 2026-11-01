#!/usr/bin/env bash
# stepGeoPrice.sh — make geo page product cards COUNTRY-AWARE: each card shows the price in
# THIS page's country currency (PK->Rs, UK->local, UAE->local, ...), baked server-side, so a
# visitor from another country never sees the Pakistani price on it. Falls back to the live
# visitor-painted price only if resolution is unavailable.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.geopricebak.$TS"; mkdir -p "$BAKDIR"
GJ="$GSZ/routes/geo.js"; GV="$GSZ/views/geo.ejs"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/geo.js" ] && cp -f "$BAKDIR/geo.js" "$GJ"; [ -f "$BAKDIR/geo.ejs" ] && cp -f "$BAKDIR/geo.ejs" "$GV"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$GJ" "$BAKDIR/geo.js"; cp -f "$GV" "$BAKDIR/geo.ejs"

echo "==> patch routes/geo.js + views/geo.ejs"
export GJ GV
node <<'NODE'
const fs=require('fs'); const GJ=process.env.GJ, GV=process.env.GV;

// 1) routes/geo.js — resolve each product's price for THIS page's country
let j=fs.readFileSync(GJ,'utf8');
if(j.indexOf('_geoPrice')>=0){ console.log('   geo.js already country-aware'); }
else {
  const anchor="const shellJson = storefront.shellJson(cats, products, settings, waNumber);";
  if(j.split(anchor).length-1!==1) throw new Error('geo.js anchor not unique');
  const ins=
"// country-aware pricing: price every product in THIS page's country, not the visitor's\n"+
"        try {\n"+
"          const _gsz = lib('gsz_pricing');\n"+
"          const _cc = (data.locale && data.locale.countryCode) || null;\n"+
"          if (_gsz && _cc) {\n"+
"            for (const _p of products) {\n"+
"              if (Number(_p.from) > 0) { try { const _pr = await _gsz.resolve({ price_pkr: _p.from, price_usd: _p.from_usd }, _cc); if (_pr) _p._geoPrice = _pr; } catch (e) {} }\n"+
"            }\n"+
"          }\n"+
"        } catch (e) {}\n"+
"        ";
  j=j.split(anchor).join(ins+anchor);
  fs.writeFileSync(GJ,j); console.log('   geo.js: per-country price resolution added');
}

// 2) views/geo.ejs — render the baked country price in the card
let v=fs.readFileSync(GV,'utf8');
if(v.indexOf('geo-price')>=0){ console.log('   geo.ejs already shows baked price'); }
else {
  const line=`'<div class="pfoot">'+(p.plans>1?'<span class="pfrom">Starts from</span>':'')+'<span class="pprice" data-pkr="'+p.from+'" data-usd="'+(p.from_usd||'')+'"></span></div>'`;
  if(v.split(line).length-1!==1) throw new Error('geo.ejs price line not unique');
  const neu=`'<div class="pfoot">'+(p.plans>1?'<span class="pfrom">Starts from</span>':'')+(p._geoPrice?'<span class="geo-price">'+esc(p._geoPrice.display)+'</span>':'<span class="pprice" data-pkr="'+p.from+'" data-usd="'+(p.from_usd||'')+'"></span>')+'</div>'`;
  v=v.split(line).join(neu);
  // add .geo-price CSS after a unique rule
  const cssAnchor=".geo-intro p{margin:0 0 12px}";
  if(v.split(cssAnchor).length-1===1){ v=v.split(cssAnchor).join(cssAnchor+"\n    .pfoot .geo-price{font-weight:800;font-size:17px;color:var(--ink,#0f1836);letter-spacing:-.01em}"); }
  fs.writeFileSync(GV,v); console.log('   geo.ejs: baked country price + style added');
}
NODE

echo "==> checks"
node --check "$GJ"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$GV"'","utf8"),{filename:"'"$GV"'"});console.log("   geo.ejs compiles OK")'

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — geo pages now price in each page's own country. Backups: $BAKDIR"
