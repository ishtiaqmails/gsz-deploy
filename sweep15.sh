#!/usr/bin/env bash
# gsz-sweep15 : per-plan hide/unhide.
#  - DB: add product_plans.hidden (safe, additive, IF NOT EXISTS)
#  - editor (product_model.ejs): Hide/Show toggle per plan + save + populate
#  - save route (adminCatalog.js): store hidden
#  - storefront (products.js, storefront.js): skip hidden plans everywhere
set -e
cd /opt/gsz

if grep -q 'pmHide(this' views/admin/product_model.ejs; then echo "sweep15 already applied"; exit 0; fi

# ---- 1) DB migration (uses the app's own .env connection) ----
cat > /opt/gsz/.gsz-mig.js <<'MIG'
require('dotenv').config({ path: '/opt/gsz/.env', override: true });
const { Pool } = require('pg');
const pool = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS, max:2 });
pool.query('ALTER TABLE product_plans ADD COLUMN IF NOT EXISTS hidden boolean NOT NULL DEFAULT false')
  .then(function(){ console.log('migrated: product_plans.hidden'); return pool.end(); })
  .then(function(){ process.exit(0); })
  .catch(function(e){ console.error('MIGRATION FAILED:', e.message); process.exit(1); });
MIG
node /opt/gsz/.gsz-mig.js || { echo "DB migration failed — aborting, no code changed"; rm -f /opt/gsz/.gsz-mig.js; exit 1; }
rm -f /opt/gsz/.gsz-mig.js

# ---- 2) back up the 4 code files ----
cp routes/adminCatalog.js       /opt/gsz/.gsz-s15-ac.bak
cp routes/products.js           /opt/gsz/.gsz-s15-pr.bak
cp lib/storefront.js            /opt/gsz/.gsz-s15-sf.bak
cp views/admin/product_model.ejs /opt/gsz/.gsz-s15-pm.bak

restore(){ cp /opt/gsz/.gsz-s15-ac.bak routes/adminCatalog.js; cp /opt/gsz/.gsz-s15-pr.bak routes/products.js; cp /opt/gsz/.gsz-s15-sf.bak lib/storefront.js; cp /opt/gsz/.gsz-s15-pm.bak views/admin/product_model.ejs; }

# ---- 3) apply all edits atomically (nothing written unless every match is exactly 1) ----
cat > /tmp/s15edit.js <<'JS'
const fs=require('fs');
const files={'routes/adminCatalog.js':0,'routes/products.js':0,'lib/storefront.js':0,'views/admin/product_model.ejs':0};
for(const f in files) files[f]=fs.readFileSync(f,'utf8');
function one(f,a,b){const s=files[f];const n=s.split(a).length-1;if(n!==1){console.error('EXPECT 1 in '+f+', got '+n+': '+a.slice(0,55));process.exit(3);}files[f]=s.replace(a,b);}

/* adminCatalog.js — editor load + save */
one('routes/adminCatalog.js',
  `avail_note FROM product_plans WHERE product_id=$1 ORDER BY sort,id', [id]`,
  `avail_note,COALESCE(hidden,false) AS hidden FROM product_plans WHERE product_id=$1 ORDER BY sort,id', [id]`);
one('routes/adminCatalog.js',
  `const pop = !!pl.popular;`,
  `const pop = !!pl.popular;\n        const hid = !!pl.hidden;`);
one('routes/adminCatalog.js',
  `avail_note=$21 WHERE id=$22 AND product_id=$23 RETURNING id`,
  `avail_note=$21,hidden=$22 WHERE id=$23 AND product_id=$24 RETURNING id`);
one('routes/adminCatalog.js',
  `anote, existingId, id]`,
  `anote, hid, existingId, id]`);
one('routes/adminCatalog.js',
  `avail_note) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::jsonb,$15::jsonb,$16::jsonb,$17,$18,$19,$20,$21,$22) RETURNING id`,
  `avail_note,hidden) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::jsonb,$15::jsonb,$16::jsonb,$17,$18,$19,$20,$21,$22,$23) RETURNING id`);
one('routes/adminCatalog.js',
  `nfpid, anote]);`,
  `nfpid, anote, hid]);`);

/* products.js — product page plan load skips hidden */
one('routes/products.js',
  `popular FROM product_plans WHERE product_id=$1 ORDER BY sort, id`,
  `popular FROM product_plans WHERE product_id=$1 AND NOT COALESCE(hidden,false) ORDER BY sort, id`);

/* storefront.js — from-price, from-usd, plan-count skip hidden */
one('lib/storefront.js',
  `MIN(price_pkr) FROM product_plans WHERE product_id=p.id) AS from_price`,
  `MIN(price_pkr) FROM product_plans WHERE product_id=p.id AND NOT COALESCE(hidden,false)) AS from_price`);
one('lib/storefront.js',
  `MIN(price_usd) FROM product_plans WHERE product_id=p.id AND price_usd>0) AS from_usd`,
  `MIN(price_usd) FROM product_plans WHERE product_id=p.id AND price_usd>0 AND NOT COALESCE(hidden,false)) AS from_usd`);
one('lib/storefront.js',
  `COUNT(*) FROM product_plans WHERE product_id=p.id)::int AS plan_count`,
  `COUNT(*) FROM product_plans WHERE product_id=p.id AND NOT COALESCE(hidden,false))::int AS plan_count`);

/* product_model.ejs — Hide/Show toggle UI + function + collect + populate + CSS */
one('views/admin/product_model.ejs',
  `+'<span class="plan-sum"><span class="plan-name">New plan</span><span class="plan-meta" data-meta></span></span>'`,
  `+'<span class="plan-sum"><span class="plan-name">New plan</span><span class="plan-meta" data-meta></span></span>'+'<button type="button" class="hide-btn" title="Hide this plan from the site" onclick="event.stopPropagation();pmHide(this)">Hide</button>'`);
one('views/admin/product_model.ejs',
  `window.pmMove=function(btn,dir){`,
  `window.pmHide=function(btn){var p=btn.closest('.plan');if(!p)return;var h=p.classList.toggle('hid');btn.textContent=h?'Show':'Hide';btn.classList.toggle('on',h);btn.title=h?'Plan is hidden - click to show':'Hide this plan from the site';var s=p.querySelector('.plan-sum');var ex=s.querySelector('.pill.hidp');if(h){if(!ex){var b=document.createElement('span');b.className='pill hidp';b.textContent='Hidden';s.appendChild(b);}}else if(ex){ex.remove();}};\n  window.pmMove=function(btn,dir){`);
one('views/admin/product_model.ejs',
  `popular:p.classList.contains('pop')`,
  `popular:p.classList.contains('pop'),hidden:p.classList.contains('hid')`);
one('views/admin/product_model.ejs',
  `if(d.popular){el.classList.add('pop');var s=el.querySelector('.plan-sum');var b=document.createElement('span');b.className='pill pop';b.textContent='★ Popular';s.appendChild(b);}`,
  `if(d.popular){el.classList.add('pop');var s=el.querySelector('.plan-sum');var b=document.createElement('span');b.className='pill pop';b.textContent='★ Popular';s.appendChild(b);}\n    if(d.hidden){el.classList.add('hid');var hb=el.querySelector('.hide-btn');if(hb){hb.textContent='Show';hb.classList.add('on');hb.title='Plan is hidden - click to show';}var hs=el.querySelector('.plan-sum');var hp=document.createElement('span');hp.className='pill hidp';hp.textContent='Hidden';hs.appendChild(hp);}`);
one('views/admin/product_model.ejs',
  `.pm .pmv-btn:hover{color:#2f74ff;border-color:#bcd0ff}`,
  `.pm .pmv-btn:hover{color:#2f74ff;border-color:#bcd0ff}.pm .hide-btn{flex:none;padding:5px 9px;border:1px solid #e2e7f0;border-radius:8px;background:#fff;color:#8a93ac;cursor:pointer;font-size:11px;font-weight:700;line-height:1}.pm .hide-btn.on{background:#fff0f0;color:#c0392b;border-color:#f3c2c2}.pm .plan.hid .plan-name{text-decoration:line-through;opacity:.55}.pm .pill.hidp{background:#fff0f0;color:#c0392b;border:1px solid #f3c2c2}`);

for(const f in files) fs.writeFileSync(f,files[f]);
console.log('all edits applied');
JS
node /tmp/s15edit.js || { echo "edit failed — reverting code (DB column stays, harmless)"; restore; exit 1; }

# ---- 4) validate ----
for g in routes/adminCatalog.js routes/products.js lib/storefront.js; do
  if ! node --check "$g" 2>/tmp/jserr; then echo "JS syntax error in $g — reverting:"; cat /tmp/jserr; restore; exit 1; fi
done
if ! node -e "require('ejs').compile(require('fs').readFileSync('views/admin/product_model.ejs','utf8'),{filename:'views/admin/product_model.ejs'})" 2>/tmp/ejserr; then
  echo "EJS compile FAILED — reverting:"; cat /tmp/ejserr; restore; exit 1
fi

pm2 restart gsz
echo "DONE: per-plan hide/unhide is live (editor toggle + storefront skips hidden plans)"
