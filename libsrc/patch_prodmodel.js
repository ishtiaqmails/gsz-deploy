'use strict';
/* Product Model — STEP 3 (backend, additive & safe):
   - GET  /admin/products/:id/model.json  → full product + plans + faqs + downloads for the model
   - POST /admin/products/model-save       → JSON save of the whole model (round-trips fulfilment
     mapping source/bot_sku/bot_plan_key/bot_type so nothing breaks; syncs required_fields from bot)
   - list route also passes cats + bots (for the model's category + mapping pickers)
   The existing form-based editor + /products/save are left intact. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_prodmodel.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/adminCatalog.js');
let s = fs.readFileSync(file, 'utf8');
let changed = false;

/* (A) list route: also load cats + bots for the model */
const LIST_OLD = "    res.render('admin/products', { rows, flash: req.query.ok || null });";
const LIST_NEW =
  "    const cats = (await pool.query('SELECT id, name FROM categories ORDER BY sort, id')).rows;\n" +
  "    const bots = (await pool.query(\"SELECT sku, name, delivery_type, types, needs, plans FROM bot_products WHERE COALESCE(is_active,true)=true AND COALESCE(missing,false)=false ORDER BY name NULLS LAST, sku\")).rows;\n" +
  "    res.render('admin/products', { rows, cats, bots, flash: req.query.ok || null });";
if (s.indexOf("{ rows, cats, bots, flash") < 0 && s.indexOf(LIST_OLD) >= 0) {
  s = s.replace(LIST_OLD, LIST_NEW); changed = true; console.log('A: list route passes cats+bots');
} else { console.log('A: present or anchor missing (skip)'); }

/* (B) new routes, inserted before the toggle route */
const ANCH = "  router.post('/products/:id/toggle', auth, async (req, res) => {";
if (s.indexOf("/products/model-save") < 0 && s.indexOf(ANCH) >= 0) {
  const NEW = String.raw`  // ---- Product Model (popup/sheet) : read ----
  router.get('/products/:id/model.json', auth, async (req, res) => {
    try {
      const id = parseInt(req.params.id, 10) || 0;
      let product = null, plans = [], faqs = [], downloads = [];
      if (id) {
        product = (await pool.query('SELECT id,name,slug,category_id,short_desc,long_desc,geo_note,image,most_selling,req_otp,has_household,has_link,link_url FROM products WHERE id=$1', [id])).rows[0] || null;
        if (product) {
          plans = (await pool.query('SELECT id,label,duration_value,duration_unit,price_pkr,price_usd,warranty,source,bot_sku,bot_plan_key,bot_type,product_note,delivery_instructions,custom_fields,required_fields,version_labels,avail_from,avail_until,popular FROM product_plans WHERE product_id=$1 ORDER BY sort,id', [id])).rows;
          faqs = (await pool.query('SELECT q,a FROM product_faqs WHERE product_id=$1 ORDER BY sort,id', [id])).rows;
          downloads = (await pool.query('SELECT label,url FROM product_downloads WHERE product_id=$1 ORDER BY sort,id', [id])).rows;
        }
      }
      res.json({ ok: true, product, plans, faqs, downloads });
    } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
  });

  // ---- Product Model (popup/sheet) : save (JSON) ----
  router.post('/products/model-save', auth, jsonBody, async (req, res) => {
    const c = await pool.connect();
    try {
      await c.query('BEGIN');
      const b = req.body || {};
      const name = (b.name || '').trim();
      if (!name) throw new Error('Product name is required');
      const category_id = parseInt(b.category_id, 10) || null;
      const short_desc = (b.short_desc || '').trim(), long_desc = (b.long_desc || '').trim(), geo_note = (b.geo_note || '').trim();
      const most_selling = !!b.most_selling, req_otp = !!b.req_otp, has_household = !!b.has_household, has_link = !!b.has_link;
      const link_url = (b.link_url || '').trim() || null;
      let id = parseInt(b.id, 10) || 0;
      if (id) {
        await c.query('UPDATE products SET name=$1,category_id=$2,short_desc=$3,long_desc=$4,geo_note=$5,most_selling=$6,req_otp=$7,has_household=$8,has_link=$9,link_url=$10 WHERE id=$11',
          [name, category_id, short_desc, long_desc, geo_note, most_selling, req_otp, has_household, has_link, link_url, id]);
      } else {
        const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') + '-' + Date.now().toString(36);
        const r = await c.query('INSERT INTO products(slug,category_id,name,short_desc,long_desc,geo_note,most_selling,req_otp,has_household,has_link,link_url,active,hidden,sort) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,true,false,COALESCE((SELECT MAX(sort)+1 FROM products),1)) RETURNING id',
          [slug, category_id, name, short_desc, long_desc, geo_note, most_selling, req_otp, has_household, has_link, link_url]);
        id = r.rows[0].id;
      }
      const plans = Array.isArray(b.plans) ? b.plans : [];
      const keepIds = [];
      for (let i = 0; i < plans.length; i++) {
        const pl = plans[i] || {};
        const label = (pl.name || '').trim(); if (!label) continue;
        const dv = (pl.duration_value === '' || pl.duration_value == null) ? null : (parseFloat(pl.duration_value) || null);
        const du = (pl.duration_unit || '').trim() || null;
        const price = parseFloat(pl.price) || 0;
        const price_usd = (pl.price_usd === '' || pl.price_usd == null) ? null : (parseFloat(pl.price_usd) || null);
        const warr = (pl.warranty || '').trim() || null;
        let source = (pl.source || 'manual').trim(); if (['inventory','bot','manual'].indexOf(source) < 0) source = 'manual';
        const bot_sku = source === 'bot' ? ((pl.bot_sku || '').trim() || null) : null;
        const bot_plan_key = source === 'bot' ? ((pl.bot_plan_key || '').trim() || null) : null;
        const bot_type = source === 'bot' ? ((pl.bot_type || '').trim() || null) : null;
        const pnote = (pl.product_note || '').trim() || null;
        const dinstr = (pl.delivery_instructions || '').trim() || null;
        const custom = JSON.stringify(Array.isArray(pl.custom_fields) ? pl.custom_fields : []);
        const vlabels = JSON.stringify(Array.isArray(pl.version_labels) ? pl.version_labels : []);
        let reqf = [];
        if (source === 'bot' && bot_sku) {
          const bp = (await c.query('SELECT needs FROM bot_products WHERE sku=$1', [bot_sku])).rows[0];
          if (bp && Array.isArray(bp.needs)) reqf = bp.needs;
        }
        const reqStr = JSON.stringify(reqf);
        const af = pl.avail_from ? new Date(pl.avail_from) : null;
        const au = pl.avail_until ? new Date(pl.avail_until) : null;
        const pop = !!pl.popular;
        const existingId = parseInt(pl.id, 10) || 0;
        if (existingId) {
          const u = await c.query('UPDATE product_plans SET label=$1,duration_value=$2,duration_unit=$3,price_pkr=$4,price_usd=$5,old_pkr=NULL,warranty=$6,source=$7,bot_sku=$8,bot_plan_key=$9,bot_type=$10,product_note=$11,delivery_instructions=$12,custom_fields=$13::jsonb,version_labels=$14::jsonb,required_fields=$15::jsonb,avail_from=$16,avail_until=$17,popular=$18,sort=$19 WHERE id=$20 AND product_id=$21 RETURNING id',
            [label, dv, du, price, price_usd, warr, source, bot_sku, bot_plan_key, bot_type, pnote, dinstr, custom, vlabels, reqStr, af, au, pop, i, existingId, id]);
          if (u.rows[0]) { keepIds.push(existingId); continue; }
        }
        const r = await c.query('INSERT INTO product_plans(product_id,label,duration_value,duration_unit,price_pkr,price_usd,warranty,source,bot_sku,bot_plan_key,bot_type,product_note,delivery_instructions,custom_fields,version_labels,required_fields,avail_from,avail_until,popular,sort) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::jsonb,$15::jsonb,$16::jsonb,$17,$18,$19,$20) RETURNING id',
          [id, label, dv, du, price, price_usd, warr, source, bot_sku, bot_plan_key, bot_type, pnote, dinstr, custom, vlabels, reqStr, af, au, pop, i]);
        keepIds.push(r.rows[0].id);
      }
      if (keepIds.length) await c.query('DELETE FROM product_plans WHERE product_id=$1 AND id <> ALL($2::int[])', [id, keepIds]);
      else await c.query('DELETE FROM product_plans WHERE product_id=$1', [id]);
      await c.query('DELETE FROM product_faqs WHERE product_id=$1', [id]);
      const faqs = Array.isArray(b.faqs) ? b.faqs : [];
      for (let i = 0; i < faqs.length; i++) { const q = (faqs[i].q || '').trim(), a = (faqs[i].a || '').trim(); if (!q || !a) continue; await c.query('INSERT INTO product_faqs(product_id,q,a,sort) VALUES($1,$2,$3,$4)', [id, q, a, i]); }
      await c.query('DELETE FROM product_downloads WHERE product_id=$1', [id]);
      const dls = Array.isArray(b.downloads) ? b.downloads : [];
      for (let i = 0; i < dls.length; i++) { const l = (dls[i].label || '').trim(), u = (dls[i].url || '').trim(); if (!l || !u) continue; await c.query('INSERT INTO product_downloads(product_id,label,url,sort) VALUES($1,$2,$3,$4)', [id, l, u, i]); }
      await c.query('COMMIT');
      res.json({ ok: true, id });
    } catch (e) { await c.query('ROLLBACK'); res.status(500).json({ ok: false, error: e.message }); }
    finally { c.release(); }
  });

`;
  s = s.replace(ANCH, NEW + ANCH); changed = true; console.log('B: model.json + model-save routes inserted');
} else { console.log('B: present or anchor missing (skip)'); }

if (changed) fs.writeFileSync(file, s);
console.log('PRODMODEL-BACKEND OK');
