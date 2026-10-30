#!/usr/bin/env bash
# stepPricing1.sh — Stage 1: deploy the pricing engine (lib/gsz_pricing.js). NOT wired to the
#   site yet (safe). Proves the live FX API is reachable from the server.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
cp -f "$SRC/gsz_pricing.js" "$GSZ/lib/gsz_pricing.js"
node --check "$GSZ/lib/gsz_pricing.js" && echo "  gsz_pricing.js ok"
echo "==> live FX check + sample conversion (USD \$15, 3% buffer)"
node -e "
const P=require('$GSZ/lib/gsz_pricing.js');
(async()=>{
  const R=await P.rates(true);
  const live = R.PKR && Math.abs(R.PKR-280)>1 ? 'LIVE' : 'fallback-or-near';
  console.log('  FX source: '+live+'  (1 USD = '+R.PKR+' PKR, '+R.GBP+' GBP, '+R.AED+' AED)');
  for(const cc of ['PK','GB','AE','US']){ const r=await P.resolve({price_pkr:2800,price_usd:15},cc,{bufferPct:3}); console.log('   '+cc+': '+r.display+' ('+r.mode+')'); }
})();
"
echo "DONE — Stage 1 engine deployed (not yet affecting the website)."
