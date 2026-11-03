#!/usr/bin/env bash
# Mobile polish: on phone cards, hide redundant control-only cells
# (row index "#" and empty-label controls like select checkbox / drag handle).
# Lives inside the single global @media block -> desktop untouched.
node <<'EOF'
const fs=require('fs');
const f='/opt/gsz/views/admin/_shell_top.ejs';
const orig=fs.readFileSync(f,'utf8');
const anchor='table.rsp td:empty{display:none}';
const cnt=orig.split(anchor).length-1;
if(cnt!==1){ console.log('FAIL anchor count='+cnt); process.exit(1); }
const add=anchor
 +'\n  table.rsp td[data-label="#"]{display:none}'
 +'\n  table.rsp td[data-label=""]{display:none}';
const s=orig.split(anchor).join(add);
try{ require('/opt/gsz/node_modules/ejs').compile(s,{includer:()=>({template:''})}); }
catch(e){ console.log('FAIL ejs '+e.message); process.exit(1); }
const bak=f+'.bak.'+Date.now();
fs.writeFileSync(bak,orig); fs.writeFileSync(f,s);
console.log('OK polish added to _shell_top.ejs  [backup '+bak+']');
EOF
echo "--- restart site ---"
pm2 restart gsz >/dev/null 2>&1 && echo "gsz restarted" || echo "restart skipped"
