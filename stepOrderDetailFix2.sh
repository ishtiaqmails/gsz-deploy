#!/usr/bin/env bash
# Refine order-detail mobile CSS: keep only safe word-break (long emails), drop the
# table-layout:fixed + width override that caused cramped rendering. order_detail.ejs only.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
ts=$(date +%s)
cp views/admin/order_detail.ejs "views/admin/order_detail.ejs.bak.$ts"
restore(){ echo "ROLLING BACK"; cp "views/admin/order_detail.ejs.bak.$ts" views/admin/order_detail.ejs; }

node <<'NODE'
const fs=require('fs');
function P(file,pairs){ let s=fs.readFileSync(file,'utf8'); for(const [a,b] of pairs){ const n=s.split(a).length-1; if(n!==1){ console.log('FAIL anchor x'+n+' ['+file+']: '+JSON.stringify(a.slice(0,80))); process.exit(1);} s=s.split(a).join(b);} fs.writeFileSync(file,s); console.log('patched '+file); }

P('views/admin/order_detail.ejs',[[
`@media(max-width:560px){
  .card table{width:100%;table-layout:fixed}
  .card table td{word-break:break-word}
  .card table td[style*="width:150px"]{width:104px}
  .fv-row{flex-wrap:wrap;gap:4px 16px}
  .fv-v{word-break:break-word;text-align:right}
  .content pre{word-break:break-word}
}`,
`@media(max-width:560px){
  .card table td{word-break:break-word}
  .fv-row{flex-wrap:wrap;gap:4px 16px}
  .fv-v{word-break:break-word;text-align:right}
  .content pre{word-break:break-word}
}`
]]);
NODE
if [ $? -ne 0 ]; then restore; exit 1; fi

echo "== EJS syntax =="
node -e "const ejs=require('/opt/gsz/node_modules/ejs');const fs=require('fs');try{ejs.compile(fs.readFileSync('views/admin/order_detail.ejs','utf8'),{filename:'views/admin/order_detail.ejs',includer:()=>({template:''})});console.log('EJS OK');}catch(e){console.log('EJS FAIL',e.message);process.exit(2);}" || { restore; exit 1; }

echo "== restart =="
pm2 restart gsz --update-env
sleep 2
pm2 list | grep -iE "gsz "
echo DONE
