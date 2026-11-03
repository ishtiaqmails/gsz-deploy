#!/usr/bin/env bash
# Fix admin phone view: orders list table reflows to cards (opt into existing .rsp CSS),
# order detail long values wrap instead of overflowing. Views only.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
ts=$(date +%s)
for f in views/admin/orders.ejs views/admin/order_detail.ejs; do cp "$f" "$f.bak.$ts"; done
restore(){ echo "ROLLING BACK"; for f in views/admin/orders.ejs views/admin/order_detail.ejs; do cp "$f.bak.$ts" "$f"; done; }

node <<'NODE'
const fs=require('fs');
function P(file,pairs){ let s=fs.readFileSync(file,'utf8'); for(const [a,b] of pairs){ const n=s.split(a).length-1; if(n!==1){ console.log('FAIL anchor x'+n+' ['+file+']: '+JSON.stringify(a.slice(0,70))); process.exit(1);} s=s.split(a).join(b);} fs.writeFileSync(file,s); console.log('patched '+file); }

// --- orders LIST: opt the table into the responsive card reflow + label each cell ---
P('views/admin/orders.ejs',[
[`<table>`, `<table class="rsp">`],
[`<td style="font-weight:700;white-space:nowrap"><%= r.order_no`, `<td data-label="Order" style="font-weight:700;white-space:nowrap"><%= r.order_no`],
[`<td><%= r.product_name %>`, `<td data-label="Product"><%= r.product_name %>`],
[`<td style="font-size:13px"><%= r.email %>`, `<td data-label="Customer" style="font-size:13px"><%= r.email %>`],
[`<td style="white-space:nowrap;font-weight:700"><%= money(`, `<td data-label="Amount" style="white-space:nowrap;font-weight:700"><%= money(`],
[`<td style="font-size:13px;color:var(--muted)"><%= r.method_name %>`, `<td data-label="Method" style="font-size:13px;color:var(--muted)"><%= r.method_name %>`],
[`<td><%- spill(r.status) %></td>`, `<td data-label="Status"><%- spill(r.status) %></td>`],
[`<td style="text-align:right"><a class="btn btn-g" style="padding:6px 12px" href="/admin/orders/`, `<td data-label="" style="text-align:right"><a class="btn btn-g" style="padding:6px 12px" href="/admin/orders/`]
]);

// --- order DETAIL: long values wrap on phone (tables + the fact-value rows) ---
P('views/admin/order_detail.ejs',[
[`<style>@media(max-width:820px){div[style*="grid-template-columns:1fr 330px"]{grid-template-columns:1fr !important}}</style>`,
`<style>
@media(max-width:820px){div[style*="grid-template-columns:1fr 330px"]{grid-template-columns:1fr !important}}
@media(max-width:560px){
  .card table{width:100%;table-layout:fixed}
  .card table td{word-break:break-word}
  .card table td[style*="width:150px"]{width:104px}
  .fv-row{flex-wrap:wrap;gap:4px 16px}
  .fv-v{word-break:break-word;text-align:right}
  .content pre{word-break:break-word}
}
</style>`]
]);
NODE
if [ $? -ne 0 ]; then restore; exit 1; fi

echo "== EJS syntax =="
for v in views/admin/orders.ejs views/admin/order_detail.ejs; do
  node -e "const ejs=require('/opt/gsz/node_modules/ejs');const fs=require('fs');try{ejs.compile(fs.readFileSync('$v','utf8'),{filename:'$v',includer:()=>({template:''})});console.log('EJS OK $v');}catch(e){console.log('EJS FAIL $v',e.message);process.exit(2);}" || { restore; exit 1; }
done

echo "== restart =="
pm2 restart gsz --update-env
sleep 2
pm2 list | grep -iE "gsz "
echo DONE
