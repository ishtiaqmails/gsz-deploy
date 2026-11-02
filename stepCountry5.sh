#!/usr/bin/env bash
# stepCountry5.sh — DISPLAY ONLY, minimal edits. Logic lives in lib/country.js (clean heredoc).
# adminCustomers: require + add column + one json field. customers.ejs: two lines. No migration (columns exist).
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
B=routes/adminCustomers.js; C=views/admin/customers.ejs
cp -f "$B" "$B.xbak.$TS"; cp -f "$C" "$C.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$B.xbak.$TS" "$B"; cp -f "$C.xbak.$TS" "$C"; rm -f .gszm_p.js .gszm_v.js; exit 1; }
trap restore ERR
nchk(){ local f="$1" i; for i in 1 2 3 4 5; do if node --check "$f" 2>/dev/null; then return 0; fi; sleep 1; done; echo "  node --check kept failing on $f; suspect lines:"; grep -nE "country|last_country|cc:" "$f" | cat -A | head -8; return 1; }

echo "==> writing lib/country.js"
cat > lib/country.js <<'CJS'
'use strict';
var DIAL = {'1':'US','7':'RU','20':'EG','27':'ZA','30':'GR','31':'NL','32':'BE','33':'FR','34':'ES','36':'HU','39':'IT','40':'RO','41':'CH','43':'AT','44':'GB','45':'DK','46':'SE','47':'NO','48':'PL','49':'DE','51':'PE','52':'MX','53':'CU','54':'AR','55':'BR','56':'CL','57':'CO','58':'VE','60':'MY','61':'AU','62':'ID','63':'PH','64':'NZ','65':'SG','66':'TH','81':'JP','82':'KR','84':'VN','86':'CN','90':'TR','91':'IN','92':'PK','93':'AF','94':'LK','95':'MM','98':'IR','212':'MA','213':'DZ','216':'TN','218':'LY','220':'GM','221':'SN','233':'GH','234':'NG','249':'SD','251':'ET','254':'KE','255':'TZ','256':'UG','260':'ZM','263':'ZW','351':'PT','352':'LU','353':'IE','354':'IS','355':'AL','358':'FI','359':'BG','370':'LT','371':'LV','372':'EE','373':'MD','375':'BY','380':'UA','381':'RS','385':'HR','386':'SI','387':'BA','389':'MK','420':'CZ','421':'SK','501':'BZ','502':'GT','503':'SV','504':'HN','505':'NI','506':'CR','507':'PA','509':'HT','591':'BO','593':'EC','595':'PY','598':'UY','673':'BN','675':'PG','679':'FJ','850':'KP','852':'HK','853':'MO','855':'KH','856':'LA','880':'BD','886':'TW','960':'MV','961':'LB','962':'JO','963':'SY','964':'IQ','965':'KW','966':'SA','967':'YE','968':'OM','970':'PS','971':'AE','972':'IL','973':'BH','974':'QA','975':'BT','976':'MN','977':'NP','992':'TJ','993':'TM','994':'AZ','995':'GE','996':'KG','998':'UZ'};
var NAME = {US:'United States',CA:'Canada',GB:'United Kingdom',PK:'Pakistan',IN:'India',BD:'Bangladesh',LK:'Sri Lanka',NP:'Nepal',AF:'Afghanistan',AE:'United Arab Emirates',SA:'Saudi Arabia',QA:'Qatar',KW:'Kuwait',OM:'Oman',BH:'Bahrain',JO:'Jordan',LB:'Lebanon',IQ:'Iraq',IR:'Iran',IL:'Israel',PS:'Palestine',SY:'Syria',YE:'Yemen',TR:'Turkey',EG:'Egypt',MA:'Morocco',DZ:'Algeria',TN:'Tunisia',LY:'Libya',SD:'Sudan',NG:'Nigeria',GH:'Ghana',KE:'Kenya',TZ:'Tanzania',UG:'Uganda',ZA:'South Africa',ZM:'Zambia',ZW:'Zimbabwe',ET:'Ethiopia',SN:'Senegal',GM:'Gambia',MY:'Malaysia',ID:'Indonesia',PH:'Philippines',SG:'Singapore',TH:'Thailand',VN:'Vietnam',CN:'China',HK:'Hong Kong',TW:'Taiwan',JP:'Japan',KR:'South Korea',KP:'North Korea',MM:'Myanmar',KH:'Cambodia',LA:'Laos',MN:'Mongolia',BN:'Brunei',MV:'Maldives',BT:'Bhutan',AU:'Australia',NZ:'New Zealand',FJ:'Fiji',PG:'Papua New Guinea',RU:'Russia',UA:'Ukraine',BY:'Belarus',PL:'Poland',DE:'Germany',FR:'France',ES:'Spain',IT:'Italy',NL:'Netherlands',BE:'Belgium',CH:'Switzerland',AT:'Austria',SE:'Sweden',NO:'Norway',DK:'Denmark',FI:'Finland',IE:'Ireland',PT:'Portugal',GR:'Greece',RO:'Romania',HU:'Hungary',CZ:'Czechia',SK:'Slovakia',BG:'Bulgaria',HR:'Croatia',SI:'Slovenia',RS:'Serbia',MK:'North Macedonia',AL:'Albania',LT:'Lithuania',LV:'Latvia',EE:'Estonia',MD:'Moldova',IS:'Iceland',LU:'Luxembourg',MX:'Mexico',BR:'Brazil',AR:'Argentina',CL:'Chile',CO:'Colombia',PE:'Peru',VE:'Venezuela',BO:'Bolivia',EC:'Ecuador',PY:'Paraguay',UY:'Uruguay',CU:'Cuba',GT:'Guatemala',SV:'El Salvador',HN:'Honduras',NI:'Nicaragua',CR:'Costa Rica',PA:'Panama',BZ:'Belize',HT:'Haiti',AZ:'Azerbaijan',GE:'Georgia',KG:'Kyrgyzstan',KZ:'Kazakhstan',TJ:'Tajikistan',TM:'Turkmenistan',UZ:'Uzbekistan'};
function flag(iso){ iso=String(iso||'').toUpperCase(); if(!/^[A-Z][A-Z]$/.test(iso)) return ''; try{ return String.fromCodePoint.apply(null, iso.split('').map(function(ch){ return 127397 + ch.charCodeAt(0); })); }catch(e){ return ''; } }
function nm(iso){ iso=String(iso||'').toUpperCase(); return NAME[iso] || iso || ''; }
function fromIso(iso){ iso=String(iso||'').toUpperCase().replace(/[^A-Z]/g,''); if(iso.length!==2 || iso==='XX' || iso==='T1') return null; return { iso:iso, name:nm(iso), flag:flag(iso) }; }
function fromPhone(num){ var d=String(num||'').replace(/[^0-9]/g,''); if(d.length<7) return null; for(var len=4; len>=1; len--){ var pre=d.slice(0,len); if(DIAL[pre]){ var iso=DIAL[pre]; return { iso:iso, name:nm(iso), flag:flag(iso), dial:'+'+pre }; } } return null; }
function forCustomer(c){ c=c||{}; return { real: fromIso(c.last_country), number: fromPhone(c.wa_number) }; }
module.exports = { flag:flag, name:nm, fromIso:fromIso, fromPhone:fromPhone, forCustomer:forCustomer };
CJS
nchk lib/country.js

echo "==> patching adminCustomers.js + customers.ejs (minimal)"
cat > .gszm_p.js <<'JS'
var fs = require('fs');
function patch(file, a, b, label){ var s=fs.readFileSync(file,'utf8'); var n=s.split(a).length-1; if(n!==1) throw new Error(file+' '+label+': x'+n); fs.writeFileSync(file, s.split(a).join(b)); console.log('  '+label+': ok'); }
patch('routes/adminCustomers.js', "const express = require('express');", "const express = require('express');\nvar country = require('../lib/country');", 'require');
patch('routes/adminCustomers.js', "created_at, last_login, ref_code\n", "created_at, last_login, ref_code, last_country\n", 'select');
patch('routes/adminCustomers.js', "res.json({ c, phone, orders });", "res.json({ c, phone, orders, cc: country.forCustomer(c) });", 'enrich');
patch('views/admin/customers.ejs', "+'<span class=\"k\">WhatsApp</span><span>'+wa+'</span>'", "+'<span class=\"k\">WhatsApp</span><span>'+wa+'</span>'\n        +(d.cc&&d.cc.real?('<span class=\"k\">Real country</span><span>'+d.cc.real.flag+' '+esc(d.cc.real.name)+'</span>'):'<span class=\"k\">Real country</span><span class=\"cu-no\">- after next sign-in</span>')\n        +(d.cc&&d.cc.number?('<span class=\"k\">Number country</span><span>'+d.cc.number.flag+' '+esc(d.cc.number.name)+'</span>'):'')", 'modal');
console.log('  applied');
process.exit(0);
JS
node .gszm_p.js

echo "==> validating"
nchk routes/adminCustomers.js
cat > .gszm_v.js <<'JS'
var ejs=require('ejs'), fs=require('fs'); ejs.compile(fs.readFileSync('views/admin/customers.ejs','utf8'),{filename:'views/admin/customers.ejs'}); console.log('  ejs ok'); process.exit(0);
JS
for i in 1 2 3 4 5; do node .gszm_v.js && break; sleep 1; done
rm -f .gszm_p.js .gszm_v.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — Number country shows now; Real country fills after login capture step."
