#!/usr/bin/env bash
# gsz-sweep30 : top-strip label "Trusted Since" -> "Since". Safe: backup, 1-match guard,
# EJS validate, auto-revert.
set -e
cd /opt/gsz
F=views/partials/top_strip.ejs
cp "$F" /opt/gsz/.gsz-s30-ts.bak
cat > /tmp/gsz_s30.js <<'PATCH'
const fs=require('fs');
const f='/opt/gsz/views/partials/top_strip.ejs';
let s=fs.readFileSync(f,'utf8');
if(s.indexOf('Trusted Since <b>')===-1){ console.error('ALREADY PATCHED'); process.exit(3); }
const a='Trusted Since <b>';
if(s.split(a).length-1!==1){ console.error('match count != 1'); process.exit(4); }
s=s.replace(a,'Since <b>');
fs.writeFileSync(f,s); console.log('PATCHED OK');
PATCH
node /tmp/gsz_s30.js || { echo "patch failed - reverting"; cp /opt/gsz/.gsz-s30-ts.bak "$F"; exit 1; }
node -e "require('ejs').compile(require('fs').readFileSync('$F','utf8'),{filename:'$F'})" || { echo "EJS error - reverting"; cp /opt/gsz/.gsz-s30-ts.bak "$F"; exit 1; }
pm2 restart gsz
echo "DONE: label changed to 'Since'."
