#!/usr/bin/env bash
# stepReviewPopup.sh — product page: a responsive "Write a review" POPUP (clickable stars, name, text).
# Opens from the top-rating link and the Reviews-tab button; AJAX-posts to /review (pending approval).
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=views/product.ejs
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .gszm_p.js .gszm_v.js; exit 1; }
trap restore ERR

echo "==> injecting review popup into $F"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
const file = 'views/product.ejs';
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf('rvpModal') >= 0) { console.log('  already patched'); process.exit(0); }
const MODAL = `<div id="rvpModal" class="rvp-ov" aria-hidden="true">
  <div class="rvp-box" role="dialog" aria-modal="true" aria-label="Write a review">
    <button type="button" class="rvp-x" id="rvpClose" aria-label="Close">&#10005;</button>
    <h3 class="rvp-ttl">Write a review</h3>
    <p class="rvp-sub">Share your experience with <%= p.name %>.</p>
    <form id="rvpForm" method="post" action="/review">
      <p class="rvp-stars-lbl">Your rating</p>
      <div class="star-input">
        <input type="radio" name="stars" id="prs5" value="5" checked><label for="prs5" title="5 stars">&#9733;</label>
        <input type="radio" name="stars" id="prs4" value="4"><label for="prs4" title="4 stars">&#9733;</label>
        <input type="radio" name="stars" id="prs3" value="3"><label for="prs3" title="3 stars">&#9733;</label>
        <input type="radio" name="stars" id="prs2" value="2"><label for="prs2" title="2 stars">&#9733;</label>
        <input type="radio" name="stars" id="prs1" value="1"><label for="prs1" title="1 star">&#9733;</label>
      </div>
      <input type="hidden" name="product" value="<%= p.slug %>">
      <input type="text" name="author" maxlength="80" placeholder="Your name" required>
      <textarea name="body" rows="3" maxlength="1500" placeholder="How was the product, delivery and support?" required></textarea>
      <button class="rvp-submit" type="submit">Submit review</button>
      <p class="rvp-note" id="rvpMsg"></p>
    </form>
  </div>
</div>
<style>
.rvp-ov{position:fixed;inset:0;z-index:100000;display:none;align-items:center;justify-content:center;background:rgba(6,8,18,.78);backdrop-filter:blur(7px);-webkit-backdrop-filter:blur(7px);padding:16px}
.rvp-ov.open{display:flex}
.rvp-box{width:100%;max-width:440px;max-height:90vh;overflow:auto;background:#0d1326;border:1px solid rgba(255,255,255,.12);border-radius:18px;padding:24px 22px;position:relative;box-shadow:0 30px 90px rgba(0,0,0,.6);animation:rvpIn .18s ease}
@keyframes rvpIn{from{opacity:0;transform:translateY(10px) scale(.98)}to{opacity:1;transform:none}}
.rvp-x{position:absolute;top:12px;right:12px;width:34px;height:34px;border-radius:50%;border:1px solid rgba(255,255,255,.14);background:rgba(255,255,255,.06);color:#fff;font-size:13px;cursor:pointer;display:flex;align-items:center;justify-content:center}
.rvp-x:hover{background:rgba(255,255,255,.14)}
.rvp-ttl{margin:0 0 2px;font-size:20px;font-weight:800;color:#eef1ff}
.rvp-sub{margin:0 0 14px;font-size:13.5px;color:#8b93bb}
.rvp-stars-lbl{font-size:11.5px;font-weight:800;letter-spacing:.4px;text-transform:uppercase;color:#8b93bb;text-align:center;margin:0 0 2px}
.star-input{display:flex;flex-direction:row-reverse;justify-content:center;margin-bottom:12px}
.star-input input{position:absolute;opacity:0;width:0;height:0}
.star-input label{color:rgba(255,255,255,.18);font-size:clamp(34px,10vw,42px);line-height:1;padding:0 4px;cursor:pointer;transition:color .1s,transform .1s}
.star-input label:hover{transform:scale(1.08)}
.star-input label:hover,.star-input label:hover ~ label{color:#f5a524}
.star-input input:checked ~ label{color:#f5a524}
#rvpForm input[type=text],#rvpForm textarea{width:100%;box-sizing:border-box;border:1px solid rgba(255,255,255,.16);border-radius:11px;padding:12px 13px;font:inherit;color:#eef1ff;background:#0b1020;margin-bottom:10px}
#rvpForm textarea{resize:vertical;min-height:84px;line-height:1.5;margin-bottom:12px}
#rvpForm input:focus,#rvpForm textarea:focus{outline:none;border-color:#3b82ff;box-shadow:0 0 0 3px rgba(59,130,255,.22)}
#rvpForm input::placeholder,#rvpForm textarea::placeholder{color:#6b7392}
.rvp-submit{width:100%;border:none;border-radius:12px;padding:13px;font:inherit;font-weight:800;color:#fff;cursor:pointer;background:linear-gradient(100deg,#8b45ff,#3b82ff 55%,#28d6ff)}
.rvp-note{text-align:center;font-size:13px;margin:10px 0 0;min-height:1px}
@media(max-width:520px){.rvp-box{border-radius:16px;padding:22px 16px}}
</style>
<script>
(function(){
  var ov=document.getElementById('rvpModal'); if(!ov) return;
  var form=document.getElementById('rvpForm'), msg=document.getElementById('rvpMsg');
  function open(){ ov.classList.add('open'); ov.setAttribute('aria-hidden','false'); document.body.style.overflow='hidden'; if(msg){msg.textContent='';} }
  function close(){ ov.classList.remove('open'); ov.setAttribute('aria-hidden','true'); document.body.style.overflow=''; }
  document.addEventListener('click', function(e){ var t=e.target.closest ? e.target.closest('a.pdp-toprev, a[href^="/review"], [data-rvp-open]') : null; if(t){ e.preventDefault(); open(); } });
  var xb=document.getElementById('rvpClose'); if(xb) xb.addEventListener('click', close);
  ov.addEventListener('click', function(e){ if(e.target===ov) close(); });
  document.addEventListener('keydown', function(e){ if(e.key==='Escape') close(); });
  if(form) form.addEventListener('submit', function(e){ e.preventDefault(); if(msg){msg.textContent='Submitting…';msg.style.color='#8b93bb';}
    var fd=new FormData(form), body=new URLSearchParams();
    fd.forEach(function(v,k){ body.append(k,v); });
    fetch('/review',{method:'POST',body:body,headers:{'Content-Type':'application/x-www-form-urlencoded'},credentials:'same-origin'}).then(function(r){ return (r&&r.url)||''; }).then(function(u){
      if(/rv=empty/.test(u)){ if(msg){msg.textContent='Please add your name and review.';msg.style.color='#ff8a8a';} return; }
      if(msg){ msg.textContent='✓ Thanks! Your review was submitted for approval.'; msg.style.color='#38d98a'; }
      try{ form.querySelector('textarea[name=body]').value=''; form.querySelector('input[name=author]').value=''; }catch(x){}
      setTimeout(close, 1900);
    }).catch(function(){ if(msg){msg.textContent='Could not submit right now. Please try again.';msg.style.color='#ff8a8a';} });
  });
})();
</script>
`;
const A = `<div class="pdp-rate">`;
const n = s.split(A).length - 1;
if (n !== 1) throw new Error('pdp-rate anchor x' + n + ' (need 1)');
s = s.split(A).join(MODAL + A);
fs.writeFileSync(file, s);
console.log('  review popup injected');
JS
node .gszm_p.js

echo "==> validating"
cat > .gszm_v.js <<'JS'
const ejs = require('ejs'), fs = require('fs');
ejs.compile(fs.readFileSync('views/product.ejs', 'utf8'), { filename: 'views/product.ejs' });
console.log('  product.ejs compiles');
JS
node .gszm_v.js
rm -f .gszm_p.js .gszm_v.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — Write a review now opens a responsive popup on product pages."
