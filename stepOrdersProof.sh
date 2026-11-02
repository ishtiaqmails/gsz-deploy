#!/usr/bin/env bash
# stepOrdersProof.sh — admin order_detail: shrink the payment proof to a thumbnail + premium lightbox.
# Click the thumbnail -> full-screen zoom (blurred backdrop, fits any device, Esc/click-out/x to close).
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=views/admin/order_detail.ejs
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .gszm_p.js .gszm_v.js; exit 1; }
trap restore ERR

echo "==> patching $F (thumbnail + lightbox)"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
const file = 'views/admin/order_detail.ejs';
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf('gszProofLb') >= 0) { console.log('  already patched'); process.exit(0); }
function one(a, b, label) {
  const n = s.split(a).length - 1;
  if (n !== 1) throw new Error(label + ': anchor x' + n + ' (need 1)');
  s = s.split(a).join(b);
  console.log('  ' + label + ': ok');
}
const LB = `
<style>
.gsz-lb{position:fixed;inset:0;z-index:99999;display:none;align-items:center;justify-content:center;background:rgba(6,8,18,.82);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);padding:16px}
.gsz-lb.open{display:flex}
.gsz-lb-img{max-width:min(94vw,1000px);max-height:84vh;width:auto;height:auto;object-fit:contain;border-radius:14px;border:1px solid rgba(255,255,255,.14);box-shadow:0 24px 80px rgba(0,0,0,.6);animation:gszLbIn .18s ease}
@keyframes gszLbIn{from{opacity:0;transform:scale(.97)}to{opacity:1;transform:none}}
.gsz-lb-bar{position:absolute;top:14px;right:14px;display:flex;gap:10px;align-items:center;z-index:2}
.gsz-lb-btn{color:#cdd6ff;text-decoration:none;font-size:13px;font-weight:600;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.14);padding:8px 14px;border-radius:999px}
.gsz-lb-btn:hover{background:rgba(255,255,255,.14)}
.gsz-lb-x{width:40px;height:40px;border-radius:999px;border:1px solid rgba(255,255,255,.14);background:rgba(255,255,255,.08);color:#fff;font-size:17px;cursor:pointer;display:flex;align-items:center;justify-content:center}
.gsz-lb-x:hover{background:rgba(255,255,255,.16)}
.proof-thumb{transition:transform .15s ease,box-shadow .15s ease}
.proof-thumb:hover{transform:translateY(-1px);box-shadow:0 10px 26px rgba(0,0,0,.3)}
@media(max-width:560px){.gsz-lb-img{max-width:94vw;max-height:80vh}.gsz-lb-btn{padding:7px 11px;font-size:12px}.gsz-lb-bar{top:10px;right:10px}}
</style>
<div id="gszProofLb" class="gsz-lb" aria-hidden="true" onclick="if(event.target===this)gszProofClose()">
  <div class="gsz-lb-bar">
    <a id="gszProofOpen" class="gsz-lb-btn" href="#" target="_blank" rel="noopener">Open original ↗</a>
    <button type="button" class="gsz-lb-x" onclick="gszProofClose()" aria-label="Close">✕</button>
  </div>
  <img id="gszProofImg" class="gsz-lb-img" src="" alt="Payment proof">
</div>
<script>
function gszProofZoom(src){try{var lb=document.getElementById('gszProofLb'),im=document.getElementById('gszProofImg'),op=document.getElementById('gszProofOpen');im.src=src;op.href=src;lb.classList.add('open');lb.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';}catch(e){}return false;}
function gszProofClose(){try{var lb=document.getElementById('gszProofLb');lb.classList.remove('open');lb.setAttribute('aria-hidden','true');document.body.style.overflow='';}catch(e){}}
document.addEventListener('keydown',function(e){if(e.key==='Escape'||e.keyCode===27)gszProofClose();});
</script>`;
const A1 = `<%- include('_shell_top', { active:'orders', title: (o.order_no || ('Order #'+o.id)) }) %>`;
one(A1, A1 + "\n" + LB, 'inject lightbox');
const A2 = `        <a href="/admin/orders/proof/<%= o.proof_file %>" target="_blank">`;
one(A2, `        <a class="proof-a" href="/admin/orders/proof/<%= o.proof_file %>" onclick="return gszProofZoom(this.getAttribute('href'))">`, 'link -> lightbox');
const A3 = `style="max-width:100%;border-radius:11px;border:1px solid var(--hair)"`;
one(A3, `class="proof-thumb" style="width:170px;max-width:100%;height:210px;object-fit:cover;object-position:top;border-radius:11px;border:1px solid var(--hair);cursor:zoom-in;display:block"`, 'thumbnail');
fs.writeFileSync(file, s);
console.log('  written');
JS
node .gszm_p.js

echo "==> validating"
cat > .gszm_v.js <<'JS'
const ejs = require('ejs'), fs = require('fs');
ejs.compile(fs.readFileSync('views/admin/order_detail.ejs', 'utf8'), { filename: 'views/admin/order_detail.ejs' });
console.log('  order_detail.ejs compiles');
JS
node .gszm_v.js
rm -f .gszm_p.js .gszm_v.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — payment proof is now a thumbnail; click it for the premium zoom popup."
