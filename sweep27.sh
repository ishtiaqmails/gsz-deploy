#!/usr/bin/env bash
# gsz-sweep27 : Instagram number on the top strip now comes from the OFFICIAL
# Instagram Graph API (reads IG_PAGE_TOKEN + IG_USER_ID from /opt/gsz/.env).
# Channel (WhatsApp) count and the delivered-order count are left exactly as-is.
# Safe: backs up, patches with a 1-match guard, validates, auto-reverts on error.
set -e
cd /opt/gsz
F=lib/socialcounts.js
cp "$F" /opt/gsz/.gsz-s27-sc.bak

cat > /tmp/gsz_sc_patch.js <<'PATCH'
const fs=require('fs');
const f='/opt/gsz/lib/socialcounts.js';
let s=fs.readFileSync(f,'utf8');
if (s.indexOf('fetchIgCount') !== -1){ console.error('ALREADY PATCHED'); process.exit(3); }
const anchorA='function get(settings){';
if (s.split(anchorA).length-1 !== 1){ console.error('anchorA!=1'); process.exit(4); }
const inject=[
'function igCreds(){',
'  try { var env=require(\'dotenv\').parse(fs.readFileSync(\'/opt/gsz/.env\')); return { tok: env.IG_PAGE_TOKEN, uid: env.IG_USER_ID }; } catch(e){ return {}; }',
'}',
'async function fetchIgCount(){',
'  var c=igCreds(); if(!c.tok||!c.uid) return null;',
'  try {',
'    var ctrl=new AbortController(); var to=setTimeout(function(){ctrl.abort();},8000);',
'    var r=await fetch(\'https://graph.facebook.com/v21.0/\'+c.uid+\'?fields=followers_count&access_token=\'+encodeURIComponent(c.tok),{signal:ctrl.signal});',
'    clearTimeout(to);',
'    var j=await r.json();',
'    if(j && typeof j.followers_count===\'number\' && j.followers_count>0) return j.followers_count;',
'  } catch(e){}',
'  return null;',
'}',
'function fetchIgCache(igUrl){',
'  if(fetching[\'__ig__\']) return; fetching[\'__ig__\']=true;',
'  fetchIgCount().then(function(n){ if(n!=null){ load(); mem[igUrl]={n:n,t:Date.now()}; persist(); } }).catch(function(){}).finally(function(){ fetching[\'__ig__\']=false; });',
'}',
''
].join('\n');
s=s.replace(anchorA, inject+anchorA);
const anchorB='if(!mem[igUrl] || now-(mem[igUrl].t||0)>TTL) fetchCache(igUrl, /([\\d.,]+)\\s*Followers/i);';
if (s.split(anchorB).length-1 !== 1){ console.error('anchorB!=1'); process.exit(5); }
const replB='if(!mem[igUrl] || now-(mem[igUrl].t||0)>TTL){ var _ic=igCreds(); if(_ic.tok&&_ic.uid) fetchIgCache(igUrl); else fetchCache(igUrl, /([\\d.,]+)\\s*Followers/i); }';
s=s.replace(anchorB, replB);
fs.writeFileSync(f,s);
console.log('PATCHED OK');
PATCH

node /tmp/gsz_sc_patch.js || { echo "patch failed - reverting"; cp /opt/gsz/.gsz-s27-sc.bak "$F"; exit 1; }
node --check "$F" || { echo "syntax error - reverting"; cp /opt/gsz/.gsz-s27-sc.bak "$F"; exit 1; }

rm -f /opt/gsz/.social-cache.json
pm2 restart gsz
echo "DONE: Instagram count is now the live Graph API value."
