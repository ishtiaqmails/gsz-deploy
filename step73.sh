#!/usr/bin/env bash
# step73 — Activation-after-MAC (UI): product-page MAC field + Validate for player
# products; Buy unlocks only after validation and carries the MAC into checkout.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step73-$TS
mkdir -p "$BAK/views" "$BAK/routes"
cp "$APP/views/product.ejs" "$BAK/views/product.ejs"
cp "$APP/views/checkout.ejs" "$BAK/views/checkout.ejs"
cp "$APP/routes/checkout.js" "$BAK/routes/checkout.js"
restore(){ echo "!! rollback"; cp "$BAK/views/product.ejs" "$APP/views/product.ejs"; cp "$BAK/views/checkout.ejs" "$APP/views/checkout.ejs"; cp "$BAK/routes/checkout.js" "$APP/routes/checkout.js"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR

echo "==> patch product.ejs / checkout"
node <<'NODE'
const fs=require('fs'); const A='/opt/gsz';
const P=[
  // product.ejs: vars
  { f:A+'/views/product.ejs',
    a:"  var PSLUG=<%- JSON.stringify(p.slug) %>, PNAME=<%- JSON.stringify(p.name) %>, WA=<%- JSON.stringify(waNumber) %>, PIMG=<%- JSON.stringify(p.image||'') %>;",
    b:"  var PSLUG=<%- JSON.stringify(p.slug) %>, PNAME=<%- JSON.stringify(p.name) %>, WA=<%- JSON.stringify(waNumber) %>, PIMG=<%- JSON.stringify(p.image||'') %>;\n  var NEEDMAC=<%= (typeof needMac!=='undefined'&&needMac)?'true':'false' %>, VMAC='';" },
  // product.ejs: buy href + gate
  { f:A+'/views/product.ejs',
    a:"    if(buy)buy.href='/checkout?p='+encodeURIComponent(PSLUG)+'&plan='+idx+'&region='+region()+(selType?('&type='+encodeURIComponent(selType)):'');",
    b:"    if(buy){ buy.href='/checkout?p='+encodeURIComponent(PSLUG)+'&plan='+idx+'&region='+region()+(selType?('&type='+encodeURIComponent(selType)):'')+(VMAC?('&mac='+encodeURIComponent(VMAC)):'');\n      if(NEEDMAC && !VMAC){ buy.classList.add('needmac'); } else { buy.classList.remove('needmac'); } }" },
  // product.ejs: handlers after add-to-cart
  { f:A+'/views/product.ejs',
    a:"    window.GSZCart.open();\n  });",
    b:"    window.GSZCart.open();\n  });\n  var macBtn=document.getElementById('macBtn');\n  if(macBtn) macBtn.addEventListener('click',function(){\n    var mi=document.getElementById('macIn'), msg=document.getElementById('macMsg');\n    var mac=(mi&&mi.value||'').trim();\n    if(msg){msg.className='mac-msg';msg.textContent='Checking\\u2026';}\n    fetch('/validate-mac?mac='+encodeURIComponent(mac)).then(function(r){return r.json();}).then(function(d){\n      if(d.valid){ VMAC=mac; if(msg){msg.className='mac-msg ok';msg.textContent=d.message||'MAC validated \\u2014 you can proceed.';} }\n      else { VMAC=''; if(msg){msg.className='mac-msg bad';msg.textContent=d.message||'Could not validate this MAC.';} }\n      update();\n    }).catch(function(){ if(msg){msg.className='mac-msg bad';msg.textContent='Could not validate right now. Please try again.';} });\n  });\n  var buyG=document.getElementById('buyBtn');\n  if(buyG) buyG.addEventListener('click',function(e){ if(NEEDMAC && !VMAC){ e.preventDefault(); var msg=document.getElementById('macMsg'); if(msg){msg.className='mac-msg bad';msg.textContent='Please validate your device MAC first.';} var mi=document.getElementById('macIn'); if(mi)mi.focus(); } });" },
  // product.ejs: MAC box before buyrow
  { f:A+'/views/product.ejs',
    a:"      <div class=\"buyrow\">",
    b:"      <% if (typeof needMac!=='undefined' && needMac) { %>\n      <div class=\"mac-box\">\n        <label class=\"mac-h\">Enter your device MAC to validate</label>\n        <div class=\"mac-row\">\n          <input id=\"macIn\" type=\"text\" placeholder=\"AA:BB:CC:DD:EE:FF\" autocomplete=\"off\">\n          <button type=\"button\" class=\"btn btn-dark\" id=\"macBtn\">Validate</button>\n        </div>\n        <div class=\"mac-msg\" id=\"macMsg\"></div>\n      </div>\n      <% } %>\n      <div class=\"buyrow\">" },
  // product.ejs: styles
  { f:A+'/views/product.ejs',
    a:"  .lt-count{font-family:var(--display);font-weight:800;font-size:15px;color:#ffb3a0;font-variant-numeric:tabular-nums}",
    b:"  .lt-count{font-family:var(--display);font-weight:800;font-size:15px;color:#ffb3a0;font-variant-numeric:tabular-nums}\n  .mac-box{margin:0 0 16px;padding:14px 16px;border:1px solid var(--line-2);border-radius:14px;background:var(--surface)}\n  .mac-h{display:block;font-size:13px;font-weight:700;margin:0 0 9px;color:var(--ink-soft)}\n  .mac-row{display:flex;gap:9px;flex-wrap:wrap}\n  .mac-row input{flex:1;min-width:180px;height:46px;border:1px solid var(--line-2);border-radius:11px;background:var(--bg0);color:var(--ink);padding:0 14px;font-size:15px;font-family:inherit}\n  .mac-row input:focus{outline:2px solid var(--b);outline-offset:1px;border-color:transparent}\n  .mac-msg{font-size:13px;margin-top:9px}\n  .mac-msg.ok{color:var(--ok)} .mac-msg.bad{color:#ff8a8a}\n  .btn.needmac{opacity:.55}" },
  // checkout route: pass prefillMac
  { f:A+'/routes/checkout.js',
    a:"        chosenType: String(req.query.type || '').trim(),",
    b:"        chosenType: String(req.query.type || '').trim(),\n        prefillMac: String(req.query.mac || '').trim()," },
  // checkout.ejs: prefill mac
  { f:A+'/views/checkout.ejs',
    a:"<input type=\"text\" name=\"mac\" placeholder=\"AA:BB:CC:DD:EE:FF\" required>",
    b:"<input type=\"text\" name=\"mac\" value=\"<%= typeof prefillMac!=='undefined'?prefillMac:'' %>\" placeholder=\"AA:BB:CC:DD:EE:FF\" required>" },
];
for(const p of P){
  let s=fs.readFileSync(p.f,'utf8');
  if(s.indexOf(p.b)>=0 && s.indexOf(p.a)<0){ console.log('   skip: '+p.f.split('/').pop()); continue; }
  if(s.indexOf(p.a)<0){ console.error('!! anchor missing in '+p.f+' :: '+p.a.slice(0,42)); process.exit(2); }
  s=s.split(p.a).join(p.b); fs.writeFileSync(p.f,s);
  console.log('   patched: '+p.f.split('/').pop());
}
NODE

echo "==> node --check + ejs compile"
node --check "$APP/routes/checkout.js"
node -e 'const ejs=require("/opt/gsz/node_modules/ejs"),fs=require("fs");["views/product.ejs","views/checkout.ejs"].forEach(function(f){ejs.compile(fs.readFileSync("/opt/gsz/"+f,"utf8"),{filename:"/opt/gsz/"+f});console.log("   compiled "+f);});'

echo "==> pm2 restart"; pm2 restart gsz --update-env >/dev/null; sleep 3
H=$(curl -s -m 15 http://127.0.0.1:3900/ || true)
grep -q '</html>' <<<"$H" || { echo "!! home broken"; false; }
SLUG=$(grep -oE '/product/[a-z0-9-]+' <<<"$H" | head -1 | sed 's#/product/##')
PP=$(curl -s -m 15 "http://127.0.0.1:3900/product/$SLUG" || true)
grep -q 'Add to cart' <<<"$PP" || { echo "!! product page broken"; false; }
if grep -qi 'Product error:' <<<"$PP"; then echo "!! product route threw"; false; fi
CO=$(curl -s -m 15 "http://127.0.0.1:3900/checkout?p=$SLUG&plan=0&region=PK&mac=AABBCCDDEEFF" || true)
grep -q 'Place order' <<<"$CO" || { echo "!! checkout broke with mac param"; false; }
trap - ERR
echo "==> step73 OK — product-page MAC validation live. Backup: $BAK"
