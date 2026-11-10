#!/usr/bin/env bash
# gsz-sweep13 : add reliable up/down (reorder) buttons to each plan row in the
# product editor. Plan order is saved as DOM order, so no backend change needed.
set -e
cd /opt/gsz
F=views/admin/product_edit.ejs

if grep -q 'movePlan(this' "$F"; then echo "sweep13 already applied"; exit 0; fi

cp "$F" /opt/gsz/.gsz-s13-pe.bak

cat > /tmp/s13edit.js <<'JS'
const fs=require('fs');
const f='views/admin/product_edit.ejs';
let s=fs.readFileSync(f,'utf8');
function one(a,b){const n=s.split(a).length-1;if(n!==1){console.error('EXPECT 1, got '+n+': '+a.slice(0,50));process.exit(3);}s=s.replace(a,b);}
function all(a,b,exp){const n=s.split(a).length-1;if(n!==exp){console.error('EXPECT '+exp+', got '+n+': '+a.slice(0,50));process.exit(4);}s=s.split(a).join(b);}

// 1) CSS for the up/down buttons
one('.prow-top .pdrag{flex:none;cursor:grab;color:var(--muted);user-select:none;font-size:17px;line-height:1}',
    '.prow-top .pdrag{flex:none;cursor:grab;color:var(--muted);user-select:none;font-size:17px;line-height:1}\n  .prow-top .pmove{display:inline-flex;flex-direction:column;gap:2px;flex:none}\n  .prow-top .pmv{width:22px;height:15px;padding:0;border:1px solid var(--hair);border-radius:5px;background:#fff;color:var(--muted);cursor:pointer;font-size:9px;line-height:1;display:flex;align-items:center;justify-content:center}\n  .prow-top .pmv:hover{color:#5b8bff;border-color:#c9b8ff}');

// 2) movePlan() just before setPop()
one('function setPop(btn){',
    'function movePlan(btn,dir){var row=btn.closest(".prow");if(!row)return;if(dir<0){var p=row.previousElementSibling;if(p&&p.classList.contains("prow"))row.parentNode.insertBefore(row,p);}else{var n=row.nextElementSibling;if(n&&n.classList.contains("prow"))row.parentNode.insertBefore(n,row);}}\nfunction setPop(btn){');

// 3) up/down buttons after each drag handle (server row + addPlan template)
all('<span class="pdrag" title="Drag to reorder">⠿</span>',
    '<span class="pdrag" title="Drag to reorder">⠿</span><span class="pmove"><button type="button" class="pmv" title="Move up" onclick="movePlan(this,-1)">▲</button><button type="button" class="pmv" title="Move down" onclick="movePlan(this,1)">▼</button></span>',
    2);

fs.writeFileSync(f,s);
console.log('up/down buttons added');
JS
node /tmp/s13edit.js || { echo "edit failed — reverting"; cp /opt/gsz/.gsz-s13-pe.bak "$F"; exit 1; }

if ! node -e "require('ejs').compile(require('fs').readFileSync('$F','utf8'),{filename:'$F'})" 2>/tmp/ejserr; then
  echo "EJS compile FAILED — reverting:"; cat /tmp/ejserr; cp /opt/gsz/.gsz-s13-pe.bak "$F"; exit 1
fi

pm2 restart gsz
echo "DONE: plan up/down reorder buttons added to the product editor"
