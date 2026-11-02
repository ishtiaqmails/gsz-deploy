#!/usr/bin/env bash
# stepReviewStars.sh — product page: clickable gold stars on the review form + a visible
# "Write a review" button (links everyone to the public /review/<slug> page). Backend unchanged.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=views/product.ejs
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .gszm_p.js .gszm_v.js; exit 1; }
trap restore ERR

echo "==> patching $F"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
const file = 'views/product.ejs';
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf('rvi-stars') >= 0) { console.log('  already patched'); process.exit(0); }
function one(a, b, label) {
  const n = s.split(a).length - 1;
  if (n !== 1) throw new Error(label + ': anchor x' + n + ' (need 1)');
  s = s.split(a).join(b);
  console.log('  ' + label + ': ok');
}

// 1) clickable stars replace the dropdown (hidden input keeps name="stars")
const A1 = `<select name="stars"><% for(var sx=5;sx>=1;sx--){ %><option value="<%= sx %>"><%= sx %> star<%= sx>1?'s':'' %></option><% } %></select>`;
const B1 = `<div class="rvi-stars" id="rviStars"><% for(var sx=1;sx<=5;sx++){ %><button type="button" class="rvi-star on" data-v="<%= sx %>" aria-label="<%= sx %> star<%= sx>1?'s':'' %>">&#9733;</button><% } %><input type="hidden" name="stars" id="rviStarsInput" value="5"></div><style>.rvi-stars{display:flex;gap:7px;align-items:center;margin:2px 0 4px}.rvi-star{background:none;border:none;padding:0;cursor:pointer;font-size:30px;line-height:1;color:rgba(255,255,255,.2);transition:color .12s,transform .12s}.rvi-star.on{color:#f5a524}.rvi-star:hover{transform:scale(1.15)}</style><script>(function(){var w=document.getElementById('rviStars');if(!w)return;var inp=document.getElementById('rviStarsInput');var ss=w.querySelectorAll('.rvi-star');function paint(n){ss.forEach(function(s){s.classList.toggle('on',Number(s.getAttribute('data-v'))<=n);});}ss.forEach(function(s){var v=Number(s.getAttribute('data-v'));s.addEventListener('click',function(){inp.value=v;paint(v);});s.addEventListener('mouseenter',function(){paint(v);});});w.addEventListener('mouseleave',function(){paint(Number(inp.value)||5);});paint(5);})();</script>`;
one(A1, B1, 'clickable stars');

// 2) a visible "Write a review" button next to "See customer reviews" (everyone can use it)
const A2 = `<a class="btn btn-ghost" href="/#reviews">See customer reviews →</a>`;
const B2 = `<a class="btn btn-ghost" href="/#reviews">See customer reviews →</a> <a class="btn btn-p" href="/review/<%= p.slug %>" style="margin-left:8px">Write a review &#9733;</a>`;
one(A2, B2, 'write-a-review button');

fs.writeFileSync(file, s);
console.log('  written');
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
echo "DONE — clickable stars + a visible Write-a-review button on product pages."
