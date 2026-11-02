#!/usr/bin/env bash
# stepCountry3.sh — DISPLAY ONLY: Real country (from last_country) + Number country (dial code) in the
# customer modal. No account.js change (login capture is a separate step). Idempotent.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
B=routes/adminCustomers.js; C=views/admin/customers.ejs
cp -f "$B" "$B.xbak.$TS"; cp -f "$C" "$C.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$B.xbak.$TS" "$B"; cp -f "$C.xbak.$TS" "$C"; rm -f .gszm_p.js .gszm_v.js; exit 1; }
trap restore ERR

echo "==> writing lib/country.js"
cat > lib/country.js <<'CJS'
'use strict';
var DIAL = {'1':'US','7':'RU','20':'EG','27':'ZA','30':'GR','31':'NL','32':'BE','33':'FR','34':'ES','36':'HU','39':'IT','40':'RO','41':'CH','43':'AT','44':'GB','45':'DK','46':'SE','47':'NO','48':'PL','49':'DE','51':'PE','52':'MX','53':'CU','54':'AR','55':'BR','56':'CL','57':'CO','58':'VE','60':'MY','61':'AU','62':'ID','63':'PH','64':'NZ','65':'SG','66':'TH','81':'JP','82':'KR','84':'VN','86':'CN','90':'TR','91':'IN','92':'PK','93':'AF','94':'LK','95':'MM','98':'IR','211':'SS','212':'MA','213':'DZ','216':'TN','218':'LY','220':'GM','221':'SN','233':'GH','234':'NG','249':'SD','251':'ET','252':'SO','254':'KE','255':'TZ','256':'UG','260':'ZM','263':'ZW','264':'NA','351':'PT','352':'LU','353':'IE','354':'IS','355':'AL','356':'MT','358':'FI','359':'BG','370':'LT','371':'LV','372':'EE','373':'MD','375':'BY','380':'UA','381':'RS','385':'HR','386':'SI','387':'BA','389':'MK','420':'CZ','421':'SK','423':'LI','501':'BZ','502':'GT','503':'SV','504':'HN','505':'NI','506':'CR','507':'PA','509':'HT','591':'BO','593':'EC','595':'PY','598':'UY','670':'TL','673':'BN','675':'PG','679':'FJ','850':'KP','852':'HK','853':'MO','855':'KH','856':'LA','880':'BD','886':'TW','960':'MV','961':'LB','962':'JO','963':'SY','964':'IQ','965':'KW','966':'SA','967':'YE','968':'OM','970':'PS','971':'AE','972':'IL','973':'BH','974':'QA','975':'BT','976':'MN','977':'NP','992':'TJ','993':'TM','994':'AZ','995':'GE','996':'KG','998':'UZ'};
var NAME = {US:'United States',CA:'Canada',GB:'United Kingdom',PK:'Pakistan',IN:'India',BD:'Bangladesh',LK:'Sri Lanka',NP:'Nepal',AF:'Afghanistan',AE:'United Arab Emirates',SA:'Saudi Arabia',QA:'Qatar',KW:'Kuwait',OM:'Oman',BH:'Bahrain',JO:'Jordan',LB:'Lebanon',IQ:'Iraq',IR:'Iran',IL:'Israel',PS:'Palestine',SY:'Syria',YE:'Yemen',TR:'Turkey',EG:'Egypt',MA:'Morocco',DZ:'Algeria',TN:'Tunisia',LY:'Libya',SD:'Sudan',SS:'South Sudan',SO:'Somalia',NG:'Nigeria',GH:'Ghana',KE:'Kenya',TZ:'Tanzania',UG:'Uganda',ZA:'South Africa',ZM:'Zambia',ZW:'Zimbabwe',ET:'Ethiopia',SN:'Senegal',GM:'Gambia',NA:'Namibia',MY:'Malaysia',ID:'Indonesia',PH:'Philippines',SG:'Singapore',TH:'Thailand',VN:'Vietnam',CN:'China',HK:'Hong Kong',TW:'Taiwan',JP:'Japan',KR:'South Korea',KP:'North Korea',MM:'Myanmar',KH:'Cambodia',LA:'Laos',MN:'Mongolia',BN:'Brunei',MV:'Maldives',BT:'Bhutan',AU:'Australia',NZ:'New Zealand',FJ:'Fiji',PG:'Papua New Guinea',TL:'Timor-Leste',RU:'Russia',UA:'Ukraine',BY:'Belarus',PL:'Poland',DE:'Germany',FR:'France',ES:'Spain',IT:'Italy',NL:'Netherlands',BE:'Belgium',CH:'Switzerland',AT:'Austria',SE:'Sweden',NO:'Norway',DK:'Denmark',FI:'Finland',IE:'Ireland',PT:'Portugal',GR:'Greece',RO:'Romania',HU:'Hungary',CZ:'Czechia',SK:'Slovakia',BG:'Bulgaria',HR:'Croatia',SI:'Slovenia',RS:'Serbia',BA:'Bosnia and Herzegovina',MK:'North Macedonia',AL:'Albania',LT:'Lithuania',LV:'Latvia',EE:'Estonia',MD:'Moldova',IS:'Iceland',LU:'Luxembourg',MT:'Malta',LI:'Liechtenstein',MX:'Mexico',BR:'Brazil',AR:'Argentina',CL:'Chile',CO:'Colombia',PE:'Peru',VE:'Venezuela',BO:'Bolivia',EC:'Ecuador',PY:'Paraguay',UY:'Uruguay',CU:'Cuba',GT:'Guatemala',SV:'El Salvador',HN:'Honduras',NI:'Nicaragua',CR:'Costa Rica',PA:'Panama',BZ:'Belize',HT:'Haiti',AZ:'Azerbaijan',GE:'Georgia',KG:'Kyrgyzstan',KZ:'Kazakhstan',TJ:'Tajikistan',TM:'Turkmenistan',UZ:'Uzbekistan'};
function flag(iso){ iso=String(iso||'').toUpperCase(); if(!/^[A-Z]{2}$/.test(iso)) return ''; try{ return String.fromCodePoint.apply(null, iso.split('').map(function(c){ return 127397 + c.charCodeAt(0); })); }catch(e){ return ''; } }
function name(iso){ iso=String(iso||'').toUpperCase(); return NAME[iso] || iso || ''; }
function fromIso(iso){ iso=String(iso||'').toUpperCase().replace(/[^A-Z]/g,''); if(iso.length!==2 || iso==='XX' || iso==='T1') return null; return { iso:iso, name:name(iso), flag:flag(iso) }; }
function fromPhone(num){ var d=String(num||'').replace(/[^0-9]/g,''); if(d.length<7) return null; for(var len=4; len>=1; len--){ var pre=d.slice(0,len); if(DIAL[pre]){ var iso=DIAL[pre]; return { iso:iso, name:name(iso), flag:flag(iso), dial:'+'+pre }; } } return null; }
module.exports = { flag:flag, name:name, fromIso:fromIso, fromPhone:fromPhone };
CJS
node --check lib/country.js

echo "==> migration (idempotent)"
PID=$(pm2 pid gsz 2>/dev/null | head -1 | tr -dc '0-9')
[ -r "/proc/$PID/environ" ] && while IFS= read -r -d '' kv; do export "$kv" 2>/dev/null || true; done < "/proc/$PID/environ"
cat > .gszm_m.js <<'JS'
(async()=>{ try{ const fs=require('fs'); const {Pool}=require('pg'); let p; try{const s=fs.readFileSync('server.js','utf8');const m=s.match(/new\s+Pool\s*\(([\s\S]*?)\)/);p=new Pool(m&&m[1].trim()?eval('('+m[1]+')'):{});}catch(e){p=new Pool();}
  await p.query('ALTER TABLE customers ADD COLUMN IF NOT EXISTS last_country text');
  await p.query('ALTER TABLE customers ADD COLUMN IF NOT EXISTS last_country_at timestamptz');
  console.log('  columns ready'); await p.end(); process.exit(0);
}catch(e){ console.log('MIG ERR',e.message); process.exit(1);} })();
JS
node .gszm_m.js; rm -f .gszm_m.js

echo "==> patching adminCustomers.js + customers.ejs"
cat > .gszm_p.js <<'JS'
const fs = require('fs');
function patch(file, a, b, label) {
  let s = fs.readFileSync(file, 'utf8');
  const n = s.split(a).length - 1;
  if (n !== 1) throw new Error(file + ' ' + label + ': anchor x' + n + ' (need 1)');
  fs.writeFileSync(file, s.split(a).join(b));
  console.log('  ' + label + ': ok');
}
patch('routes/adminCustomers.js', `const express = require('express');`,
  `const express = require('express');\nconst country = require('../lib/country');`,
  'require country');
patch('routes/adminCustomers.js',
  `SELECT id, name, email, email_verified, wa_number, wa_verified, blocked, created_at, last_login, ref_code`,
  `SELECT id, name, email, email_verified, wa_number, wa_verified, blocked, created_at, last_login, ref_code, last_country`,
  'detail select');
patch('routes/adminCustomers.js', `      res.json({ c, phone, orders });`,
  `      const real_country = country.fromIso(c.last_country);\n      const number_country = country.fromPhone(String(c.wa_number||'').replace(/[^0-9]/g,''));\n      res.json({ c, phone, orders, real_country, number_country });`,
  'enrich json');
patch('views/admin/customers.ejs',
  `+'<span class="k">WhatsApp</span><span>'+wa+'</span>'`,
  `+'<span class="k">WhatsApp</span><span>'+wa+'</span>'\n        +(d.real_country?('<span class="k">Real country</span><span>'+d.real_country.flag+' '+esc(d.real_country.name)+'</span>'):'<span class="k">Real country</span><span class="cu-no">- shows after next sign-in</span>')\n        +(d.number_country?('<span class="k">Number country</span><span>'+d.number_country.flag+' '+esc(d.number_country.name)+' <span class="cu-no">'+esc(d.number_country.dial||'')+'</span></span>'):'')`,
  'modal countries');
console.log('  all patches applied');
process.exit(0);
JS
node .gszm_p.js

echo "==> validating"
node --check routes/adminCustomers.js
cat > .gszm_v.js <<'JS'
const ejs = require('ejs'), fs = require('fs');
ejs.compile(fs.readFileSync('views/admin/customers.ejs', 'utf8'), { filename: 'views/admin/customers.ejs' });
console.log('  customers.ejs compiles'); process.exit(0);
JS
node .gszm_v.js
rm -f .gszm_p.js .gszm_v.js
echo "   checks passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — Number country shows now; Real country fills once login capture is added."
