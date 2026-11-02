#!/usr/bin/env bash
# stepCountryFlag.sh — render flags as <img> (desktop/Windows show "PK" for emoji flags). lib/country.js flag() only.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=lib/country.js
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .gszm_fl.js; exit 1; }
trap restore ERR

echo "==> swapping emoji flag for <img> (works on every device)"
cat > .gszm_fl.js <<'JS'
var fs = require('fs');
var f = 'lib/country.js';
var s = fs.readFileSync(f, 'utf8');
var a = "function flag(iso){ iso=String(iso||'').toUpperCase(); if(!/^[A-Z][A-Z]$/.test(iso)) return ''; try{ return String.fromCodePoint.apply(null, iso.split('').map(function(ch){ return 127397 + ch.charCodeAt(0); })); }catch(e){ return ''; } }";
var b = "function flag(iso){ iso=String(iso||'').toUpperCase(); if(!/^[A-Z][A-Z]$/.test(iso)) return ''; var lc=iso.toLowerCase(); return '<img src=\"https://flagcdn.com/w40/'+lc+'.png\" srcset=\"https://flagcdn.com/w80/'+lc+'.png 2x\" alt=\"'+iso+'\" width=\"22\" height=\"15\" loading=\"lazy\" style=\"display:inline-block;width:22px;height:15px;object-fit:cover;border-radius:2px;vertical-align:-3px;box-shadow:0 0 0 1px rgba(0,0,0,.12)\">'; }";
var n = s.split(a).length - 1;
if (n !== 1) {
  console.log('  ANCHOR MATCH x' + n + ' — current flag line:');
  s.split('\n').forEach(function(l, i){ if (l.indexOf('function flag(') >= 0) console.log('   ' + (i+1) + ': ' + l.trim()); });
  process.exit(2);
}
fs.writeFileSync(f, s.split(a).join(b));
console.log('  flag(): ok');
process.exit(0);
JS
node .gszm_fl.js
node --check "$F"
rm -f .gszm_fl.js
echo "   check passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — flags now render as images on desktop and phone (no more 'PK')."
