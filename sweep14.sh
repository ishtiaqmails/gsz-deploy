#!/usr/bin/env bash
# gsz-sweep14 : add working up/down (reorder) buttons to plan rows in the LIVE
# product editor modal (product_model.ejs). Replaces the dead drag grip. Plans
# save in DOM order, so reordering persists with no backend change.
# Also reverts the stray edit sweep13 made to the legacy product_edit.ejs.
set -e
cd /opt/gsz
F=views/admin/product_model.ejs

if grep -q 'pmMove(this' "$F"; then echo "sweep14 already applied"; exit 0; fi

# revert the stray edit on the legacy (unused) editor
if [ -f /opt/gsz/.gsz-s13-pe.bak ]; then cp /opt/gsz/.gsz-s13-pe.bak views/admin/product_edit.ejs; echo "reverted legacy product_edit.ejs"; fi

cp "$F" /opt/gsz/.gsz-s14-pm.bak

cat > /tmp/s14edit.js <<'JS'
const fs=require('fs');
const f='views/admin/product_model.ejs';
let s=fs.readFileSync(f,'utf8');
function one(a,b){const n=s.split(a).length-1;if(n!==1){console.error('EXPECT 1, got '+n+' for '+a.slice(0,45));process.exit(3);}s=s.replace(a,b);}

// 1) replace the dead grip with working up/down buttons
one(`+'<span class="plan-grip">⠿</span>'`,
    `+'<span class="plan-mv"><button type="button" class="pmv-btn" title="Move up" onclick="event.stopPropagation();pmMove(this,-1)">▲</button><button type="button" class="pmv-btn" title="Move down" onclick="event.stopPropagation();pmMove(this,1)">▼</button></span>'`);

// 2) the reorder function
one(`window.pmCounts=function(){`,
    `window.pmMove=function(btn,dir){var row=btn.closest('.plan');if(!row)return;var box=document.getElementById('pmPlans');if(dir<0){var p=row.previousElementSibling;if(p&&p.classList.contains('plan'))box.insertBefore(row,p);}else{var n=row.nextElementSibling;if(n&&n.classList.contains('plan'))box.insertBefore(n,row);}};\n  window.pmCounts=function(){`);

// 3) swap grip CSS for button CSS
one(`.pm .plan-grip{color:#8a93ac;cursor:grab;font-size:15px}`,
    `.pm .plan-mv{display:inline-flex;flex-direction:column;gap:2px;margin-right:2px}.pm .pmv-btn{width:20px;height:14px;padding:0;border:1px solid #e2e7f0;border-radius:4px;background:#fff;color:#8a93ac;cursor:pointer;font-size:8px;line-height:1;display:flex;align-items:center;justify-content:center}.pm .pmv-btn:hover{color:#2f74ff;border-color:#bcd0ff}`);

fs.writeFileSync(f,s);
console.log('reorder buttons added');
JS
node /tmp/s14edit.js || { echo "edit failed — reverting"; cp /opt/gsz/.gsz-s14-pm.bak "$F"; exit 1; }

# validate templates compile
for g in "$F" views/admin/product_edit.ejs; do
  if ! node -e "require('ejs').compile(require('fs').readFileSync('$g','utf8'),{filename:'$g'})" 2>/tmp/ejserr; then
    echo "EJS compile FAILED $g — reverting:"; cat /tmp/ejserr; cp /opt/gsz/.gsz-s14-pm.bak "$F"; exit 1
  fi
done

pm2 restart gsz
echo "DONE: plan up/down reorder buttons added to the live product editor"
