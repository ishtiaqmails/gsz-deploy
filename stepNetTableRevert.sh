#!/usr/bin/env bash
# Remove the global .card table display override (it interferes with views that already have
# their own mobile card reflow, e.g. customers). Keep the harmless pre/input/img rules.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
ts=$(date +%s)
cp views/admin/_shell_top.ejs "views/admin/_shell_top.ejs.bak.$ts"
restore(){ echo "ROLLING BACK"; cp "views/admin/_shell_top.ejs.bak.$ts" views/admin/_shell_top.ejs; }

node <<'NODE'
const fs=require('fs');
function P(file,pairs){ let s=fs.readFileSync(file,'utf8'); for(const [a,b] of pairs){ const n=s.split(a).length-1; if(n!==1){ console.log('FAIL anchor x'+n+' ['+file+']: '+JSON.stringify(a.slice(0,60))); process.exit(1);} s=s.split(a).join(b);} fs.writeFileSync(file,s); console.log('patched '+file); }

P('views/admin/_shell_top.ejs',[[
`/*gsz_admin_mobile_net*/
@media(max-width:560px){
  .card table:not(.rsp){display:block;max-width:100%;overflow-x:auto;-webkit-overflow-scrolling:touch}
  .card pre{white-space:pre-wrap;word-break:break-word}
  .card input:not([type=checkbox]):not([type=radio]),.card select,.card textarea{max-width:100%}
  .card img{max-width:100%;height:auto}
}
/*admin-app-model*/`,
`/*gsz_admin_mobile_net*/
@media(max-width:560px){
  .card pre{white-space:pre-wrap;word-break:break-word}
  .card input:not([type=checkbox]):not([type=radio]),.card select,.card textarea{max-width:100%}
  .card img{max-width:100%;height:auto}
}
/*admin-app-model*/`
]]);
NODE
if [ $? -ne 0 ]; then restore; exit 1; fi

echo "== EJS syntax =="
node -e "const ejs=require('/opt/gsz/node_modules/ejs');const fs=require('fs');try{ejs.compile(fs.readFileSync('views/admin/_shell_top.ejs','utf8'),{filename:'views/admin/_shell_top.ejs',includer:()=>({template:''})});console.log('EJS OK');}catch(e){console.log('EJS FAIL',e.message);process.exit(2);}" || { restore; exit 1; }

echo "== restart =="
pm2 restart gsz --update-env
sleep 2
pm2 list | grep -iE "gsz "
echo DONE
