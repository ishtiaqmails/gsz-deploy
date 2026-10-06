#!/usr/bin/env bash
# step72 — Activation-after-MAC (backend): botapi.validateMac + /validate-mac route
# (graceful when the bot endpoint is absent) + product "needs MAC" detection.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step72-$TS
mkdir -p "$BAK/lib" "$BAK/routes"
cp "$APP/lib/botapi.js" "$BAK/lib/botapi.js"
cp "$APP/routes/checkout.js" "$BAK/routes/checkout.js"
cp "$APP/routes/products.js" "$BAK/routes/products.js"
restore(){ echo "!! rollback"; cp "$BAK/lib/botapi.js" "$APP/lib/botapi.js"; cp "$BAK/routes/checkout.js" "$APP/routes/checkout.js"; cp "$BAK/routes/products.js" "$APP/routes/products.js"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> patch botapi / checkout / products"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const P=[
  // botapi: validateMac fn + export
  { f:A+'/lib/botapi.js',
    a:"function submitOrder(payload) { return req('POST', '/api/submit-order', payload, 10000); }",
    b:"function submitOrder(payload) { return req('POST', '/api/submit-order', payload, 10000); }\nfunction validateMac(mac) { return req('GET', '/api/validate-mac/' + encodeURIComponent(mac), null, 8000); }" },
  { f:A+'/lib/botapi.js',
    a:"submitOrder, notify, ping, clearCache };",
    b:"submitOrder, notify, validateMac, ping, clearCache };" },
  // checkout: /validate-mac route (graceful)
  { f:A+'/routes/checkout.js',
    a:"  // ---- checkout page (single product) ----",
    b:"  // ---- MAC validation (IPTV player activation) ----\n  router.get('/validate-mac', async (req, res) => {\n    const mac = String(req.query.mac || '').trim();\n    const clean = mac.replace(/[^0-9a-fA-F]/g, '');\n    if (clean.length < 12) return res.json({ valid: false, message: 'Enter a valid MAC address (e.g. AA:BB:CC:DD:EE:FF).' });\n    if (!botapi.configured()) return res.json({ valid: true, pending: true, message: 'MAC noted \\u2014 we\\u2019ll validate and activate right after payment.' });\n    try {\n      const r = await botapi.validateMac(mac);\n      if (r && typeof r.valid !== 'undefined') return res.json({ valid: !!r.valid, message: r.message || (r.valid ? 'MAC looks good \\u2014 you can proceed.' : 'This MAC could not be validated.') });\n      return res.json({ valid: true, pending: true, message: 'MAC noted \\u2014 we\\u2019ll validate and activate right after payment.' });\n    } catch (e) { return res.json({ valid: true, pending: true, message: 'MAC noted \\u2014 we\\u2019ll validate and activate right after payment.' }); }\n  });\n\n  // ---- checkout page (single product) ----" },
  // products.js: detect needMac from bot delivery_type
  { f:A+'/routes/products.js',
    a:"      const botTypes = {};",
    b:"      const botTypes = {}; let needMac = false;" },
  { f:A+'/routes/products.js',
    a:"          (await pool.query('SELECT sku, types FROM bot_products WHERE sku = ANY($1)', [skus])).rows\n            .forEach(b => { botTypes[b.sku] = Array.isArray(b.types) ? b.types : []; });",
    b:"          (await pool.query('SELECT sku, types, delivery_type FROM bot_products WHERE sku = ANY($1)', [skus])).rows\n            .forEach(b => { botTypes[b.sku] = Array.isArray(b.types) ? b.types : []; if (['hotplayer','ibosol','zayron'].includes(b.delivery_type)) needMac = true; });" },
  { f:A+'/routes/products.js',
    a:"        p: prow, plans, faqs, downloads, similar, accent, rating, orders, payNames",
    b:"        p: prow, plans, faqs, downloads, similar, accent, rating, orders, payNames, needMac" },
];
for(const p of P){
  let s=fs.readFileSync(p.f,'utf8');
  if(s.indexOf(p.b)>=0 && s.indexOf(p.a)<0){ console.log('   skip: '+p.f.split('/').pop()); continue; }
  if(s.indexOf(p.a)<0){ console.error('!! anchor missing in '+p.f+' :: '+p.a.slice(0,42)); process.exit(2); }
  s=s.split(p.a).join(p.b); fs.writeFileSync(p.f,s);
  console.log('   patched: '+p.f.split('/').pop());
}
NODE

echo "==> node --check"
node --check "$APP/lib/botapi.js"
node --check "$APP/routes/checkout.js"
node --check "$APP/routes/products.js"

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
SLUG=$(grep -oE '/product/[a-z0-9-]+' <<<"$H" | head -1 | sed 's#/product/##')
grep -q 'Add to cart' <<<"$(curl -s -m 15 "http://127.0.0.1:3900/product/$SLUG" || true)" || { echo "!! product page broken"; false; }
echo "==> test /validate-mac"
VM=$(curl -s -m 10 "http://127.0.0.1:3900/validate-mac?mac=AABBCCDDEEFF" || true)
echo "   response: $VM"
grep -q 'valid' <<<"$VM" || { echo "!! validate-mac did not return JSON"; false; }
VM2=$(curl -s -m 10 "http://127.0.0.1:3900/validate-mac?mac=xx" || true)
grep -q '"valid":false' <<<"$VM2" || { echo "!! short MAC not rejected"; false; }
trap - ERR
echo "==> step72 OK — MAC validation backend live. Backup: $BAK"
