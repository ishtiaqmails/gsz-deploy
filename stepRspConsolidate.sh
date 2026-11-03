#!/usr/bin/env bash
# Consolidate admin responsive tables onto the single global .rsp system.
# Removes the obsolete per-view mobile reflow block (the @media that hides thead)
# from column-list views only. order_detail is intentionally excluded (label/value).
node <<'EOF'
const fs=require('fs');
const ejs=require('ejs');
const names=['customers','categories','inventory','inventory_manage','products'];
const strip=x=>x.replace(/\s+/g,'');
for(const n of names){
  const f='/opt/gsz/views/admin/'+n+'.ejs';
  let s;
  try{ s=fs.readFileSync(f,'utf8'); }catch(e){ console.log('SKIP missing: '+n); continue; }
  const orig=s; let removed=0, idx=0, guard=0;
  while(guard++<80){
    const m=s.indexOf('@media', idx); if(m<0) break;
    const b=s.indexOf('{', m); if(b<0) break;
    let i=b, depth=0, end=-1;
    for(;i<s.length;i++){ if(s[i]==='{')depth++; else if(s[i]==='}'){depth--; if(depth===0){end=i;break;}} }
    if(end<0) break;
    const body=s.slice(b+1,end);
    if(strip(body).indexOf('thead{display:none}')>=0){ s=s.slice(0,m)+s.slice(end+1); removed++; idx=m; }
    else { idx=end+1; }
  }
  if(!removed){ console.log('NOCHANGE '+n+' (no reflow block found)'); continue; }
  try{ ejs.compile(s,{includer:()=>({template:''})}); }
  catch(e){ console.log('FAIL ejs '+n+' -> reverted :: '+e.message); continue; }
  const bak=f+'.bak.'+Date.now();
  fs.writeFileSync(bak,orig); fs.writeFileSync(f,s);
  console.log('OK '+n+': removed '+removed+' reflow block(s)  [backup '+bak+']');
}
console.log('DONE');
EOF
echo "--- restart site ---"
pm2 restart gsz >/dev/null 2>&1 && echo "gsz restarted" || echo "restart skipped"
