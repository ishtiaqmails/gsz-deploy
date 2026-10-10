'use strict';
/* In-model Buy Now backend — resolves a product+plan to what the checkout model needs
   (price, delivery fields, type options, stock). Inserted into routes/checkout.js so it
   reuses botMeta/customerFields/wantsActEmail/availability/withinWindow directly (no logic
   duplicated). The actual order still goes through the existing POST /checkout.
   GET /account/tools/buy-info?slug=&plan=&type=
     -> { ok, name, slug, planIdx, planLabel, price_pkr, deliveryType, needFields:[],
          wantsActEmail, available, typeOptions:[{key,label}] }
   Idempotent. Inserts before the module's final `return router;`. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_buyinfo.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/checkout.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/account/tools/buy-info') >= 0) { console.log('skip (already): buy-info present'); console.log('BUYINFO PATCH OK'); process.exit(0); }

const ROUTES =
"  // ---- IN-MODEL BUY: resolve product+plan -> fields/price/stock (reuses checkout helpers) ----\n" +
"  router.get('/account/tools/buy-info', async (req, res) => {\n" +
"    try{\n" +
"      const slug=String(req.query.slug||'').trim(); const planIdx=parseInt(req.query.plan,10);\n" +
"      const prow=(await pool.query('SELECT id,name,slug FROM products WHERE slug=$1 AND active AND NOT hidden',[slug])).rows[0];\n" +
"      if(!prow) return res.json({ ok:false, error:'Product not found.' });\n" +
"      const plans=(await pool.query('SELECT * FROM product_plans WHERE product_id=$1 ORDER BY sort,id',[prow.id])).rows;\n" +
"      if(!plans.length) return res.json({ ok:false, error:'No plans available.' });\n" +
"      const idx=(Number.isFinite(planIdx) && planIdx>=0 && planIdx<plans.length)?planIdx:0;\n" +
"      const plan=plans[idx];\n" +
"      if(!withinWindow(plan)) return res.json({ ok:false, error:'This plan is no longer available.' });\n" +
"      const meta=await botMeta(plan);\n" +
"      if(meta && meta.missing) return res.json({ ok:false, error:'This item is currently unavailable.' });\n" +
"      const dt=(meta && meta.deliveryType)||'';\n" +
"      const needFields=customerFields(dt);\n" +
"      let avail={available:true}; try{ avail=await availability(plan, dt); }catch(e){}\n" +
"      let typeOptions=[];\n" +
"      if(plan.source==='bot' && plan.bot_sku && !plan.bot_type){ try{ const bp=(await pool.query('SELECT types FROM bot_products WHERE sku=$1',[plan.bot_sku])).rows[0]; if(bp && Array.isArray(bp.types)) typeOptions=bp.types.map(function(t){ return { key:String(t.key||''), label:String(t.label||t.name||t.key||'') }; }).filter(function(t){return t.key;}); }catch(e){} }\n" +
"      res.json({ ok:true, name:prow.name, slug:prow.slug, planIdx:idx, planLabel:plan.label, price_pkr:Number(plan.price_pkr)||0,\n" +
"        deliveryType:dt, needFields:needFields, wantsActEmail:wantsActEmail(dt),\n" +
"        available: !!(avail && avail.available), typeOptions:typeOptions });\n" +
"    }catch(e){ res.json({ ok:false, error:'Could not load this product right now.' }); }\n" +
"  });\n\n";

const anchor = "  return router;";
const i = s.lastIndexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: final return router; not found in checkout.js');
s = s.slice(0, i) + ROUTES + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: added GET /account/tools/buy-info to checkout.js');
console.log('BUYINFO PATCH OK');
