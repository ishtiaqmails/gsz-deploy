#!/usr/bin/env bash
# stepReviewCTA.sh — make leaving a review easy & visible: a "Write a review" link at the top of
# each product page (by the rating) and in the site footer. No tab-digging. Backend unchanged.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F1=views/product.ejs
F2=views/partials/store_bottom.ejs
cp -f "$F1" "$F1.xbak.$TS"; cp -f "$F2" "$F2.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F1.xbak.$TS" "$F1"; cp -f "$F2.xbak.$TS" "$F2"; rm -f .gszm_p.js .gszm_v.js; exit 1; }
trap restore ERR

echo "==> patching product top-rating + footer"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
function patch(file, a, b, guard, label) {
  let s = fs.readFileSync(file, 'utf8');
  if (guard && s.indexOf(guard) >= 0) { console.log('  ' + label + ': already present'); return; }
  const n = s.split(a).length - 1;
  if (n !== 1) throw new Error(label + ': anchor x' + n + ' (need 1)');
  fs.writeFileSync(file, s.split(a).join(b));
  console.log('  ' + label + ': ok');
}

// 1) product page — a visible "Write a review" right by the top rating
patch('views/product.ejs',
  `<span class="rmut"><%= soldNum.toLocaleString('en-US') %>+ sold</span>`,
  `<span class="rmut"><%= soldNum.toLocaleString('en-US') %>+ sold</span><span class="rsep">·</span><a href="/review/<%= p.slug %>" class="pdp-toprev" style="color:#f5a524;font-weight:700;text-decoration:none;white-space:nowrap">Write a review</a>`,
  'pdp-toprev', 'product top-rating link');

// 2) site footer — "Write a review" (every page)
patch('views/partials/store_bottom.ejs',
  `<a href="/faq">FAQ &amp; policies</a>`,
  `<a href="/faq">FAQ &amp; policies</a>
        <a href="/review">Write a review</a>`,
  '"/review">Write a review', 'footer link');
JS
node .gszm_p.js

echo "==> validating"
cat > .gszm_v.js <<'JS'
const ejs = require('ejs'), fs = require('fs');
['views/product.ejs','views/partials/store_bottom.ejs'].forEach(function(f){ ejs.compile(fs.readFileSync(f,'utf8'),{filename:f}); console.log('  compiles: '+f); });
JS
node .gszm_v.js
rm -f .gszm_p.js .gszm_v.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — Write a review is now at the top of product pages and in the footer."
