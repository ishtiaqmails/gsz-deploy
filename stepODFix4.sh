#!/usr/bin/env bash
# Order detail PHONE ONLY fix: stack the label/value tables as two-line blocks and kill the
# stray pseudo-element duplication. Desktop (>560px) untouched. No fields removed. CSS-only.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
ts=$(date +%s)
cp views/admin/order_detail.ejs "views/admin/order_detail.ejs.bak.$ts"
restore(){ echo "ROLLING BACK"; cp "views/admin/order_detail.ejs.bak.$ts" views/admin/order_detail.ejs; }

node <<'NODE'
const fs=require('fs');
function P(file,pairs){ let s=fs.readFileSync(file,'utf8'); for(const [a,b] of pairs){ const n=s.split(a).length-1; if(n!==1){ console.log('FAIL anchor x'+n+' ['+file+']: '+JSON.stringify(a.slice(0,80))); process.exit(1);} s=s.split(a).join(b);} fs.writeFileSync(file,s); console.log('patched '+file); }

P('views/admin/order_detail.ejs',[[
`<style>
@media(max-width:820px){div[style*="grid-template-columns:1fr 330px"]{grid-template-columns:1fr !important}}
@media(max-width:560px){
  .card table,.card table tbody{display:block;width:100%}
  .card table tr{display:flex;flex-wrap:wrap;justify-content:space-between;gap:1px 14px;padding:9px 0;border-bottom:1px solid var(--hair)}
  .card table tr:last-child{border-bottom:0}
  .card table td{display:block;padding:0;border:0}
  .card table td:first-child{color:var(--muted);font-weight:600;flex:0 0 auto;width:auto !important}
  .card table td:last-child{flex:1 1 100%;text-align:left;word-break:break-word}
  .fv-row{flex-wrap:wrap;gap:1px 16px}
  .fv-k{width:100%}
  .fv-v{width:100%;text-align:left;word-break:break-word}
  .content pre{word-break:break-word}
}
</style>`,
`<style>
@media(max-width:820px){div[style*="grid-template-columns:1fr 330px"]{grid-template-columns:1fr !important}}
@media(max-width:560px){
  .card table{display:block;width:100%;border-collapse:collapse}
  .card table thead{display:none}
  .card table tbody{display:block;width:100%}
  .card table tr{display:block;width:100%;padding:8px 0;border-bottom:1px solid var(--hair)}
  .card table tr:last-child{border-bottom:none}
  .card table td{display:block;width:100% !important;padding:0;border:none;text-align:left;white-space:normal}
  .card table td:before,.card table td:after{content:none !important;display:none !important}
  .card table td:first-child{color:var(--muted);font-weight:600;font-size:12.5px;margin-bottom:2px}
  .card table td:last-child{font-size:14px;word-break:break-word}
  .fv-row{flex-wrap:wrap;gap:1px 16px}
  .fv-k{width:100%}
  .fv-v{width:100%;text-align:left;word-break:break-word}
  .content pre{word-break:break-word}
}
</style>`
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
