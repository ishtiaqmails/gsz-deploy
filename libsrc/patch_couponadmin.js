'use strict';
/* #80 — admin coupons: load products for the picker + the editing coupon's scope, and
   on save rebuild coupon_products from the form (scope=all|products, product_ids[]).
   routes/adminCoupons.js. Two anchored edits. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_couponadmin.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/adminCoupons.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/*couponScopeSave*/') >= 0) { console.log('skip (already): admin coupon scope'); console.log('COUPONADMIN OK'); process.exit(0); }

/* 0) rows query: add per-coupon product scope count (for the list) */
const ROWS = "    const rows = (await pool.query('SELECT * FROM coupons ORDER BY featured DESC, id DESC')).rows;";
if (s.indexOf(ROWS) < 0) throw new Error('ANCHOR MISS: coupons rows query');
s = s.replace(ROWS, "    const rows = (await pool.query('SELECT c.*, (SELECT count(*)::int FROM coupon_products cp WHERE cp.coupon_id=c.id) AS scope_count FROM coupons c ORDER BY c.featured DESC, c.id DESC')).rows;");

/* 1) GET render: add products + scopeIds */
const GET = "    res.render('admin/coupons', { rows, edit, toDTLocal, flash: req.query.ok || null });";
if (s.indexOf(GET) < 0) throw new Error('ANCHOR MISS: coupons render');
const GET2 =
  "    let products = []; try { products = (await pool.query(\"SELECT id, name FROM products WHERE active AND NOT hidden ORDER BY name\")).rows; } catch (e) {}\n" +
  "    let scopeIds = []; if (edit) { try { scopeIds = (await pool.query('SELECT product_id FROM coupon_products WHERE coupon_id=$1', [edit.id])).rows.map(function (r) { return Number(r.product_id); }); } catch (e) {} }\n" +
  "    res.render('admin/coupons', { rows, edit, products, scopeIds, toDTLocal, flash: req.query.ok || null });";
s = s.replace(GET, GET2);

/* 2) POST save: capture coupon id, then rebuild coupon_products */
const SAVE =
  "        if (id) {\n" +
  "          await pool.query('UPDATE coupons SET code=$1,kind=$2,value=$3,min_order_pkr=$4,max_discount_pkr=$5,expires_at=$6,usage_limit=$7,active=$8,featured=$9 WHERE id=$10',\n" +
  "            [code, kind, value, min, maxd, exp, limit, active, featured, id]);\n" +
  "        } else {\n" +
  "          await pool.query('INSERT INTO coupons(code,kind,value,min_order_pkr,max_discount_pkr,expires_at,usage_limit,active,featured) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)',\n" +
  "            [code, kind, value, min, maxd, exp, limit, active, featured]);\n" +
  "        }\n" +
  "        res.redirect('/admin/coupons?ok=' + encodeURIComponent('Saved ' + code));";
if (s.indexOf(SAVE) < 0) throw new Error('ANCHOR MISS: coupon save block');
const SAVE2 =
  "        let cid = id; /*couponScopeSave*/\n" +
  "        if (id) {\n" +
  "          await pool.query('UPDATE coupons SET code=$1,kind=$2,value=$3,min_order_pkr=$4,max_discount_pkr=$5,expires_at=$6,usage_limit=$7,active=$8,featured=$9 WHERE id=$10',\n" +
  "            [code, kind, value, min, maxd, exp, limit, active, featured, id]);\n" +
  "        } else {\n" +
  "          const _r = await pool.query('INSERT INTO coupons(code,kind,value,min_order_pkr,max_discount_pkr,expires_at,usage_limit,active,featured) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id',\n" +
  "            [code, kind, value, min, maxd, exp, limit, active, featured]);\n" +
  "          cid = _r.rows[0].id;\n" +
  "        }\n" +
  "        try {\n" +
  "          await pool.query('DELETE FROM coupon_products WHERE coupon_id=$1', [cid]);\n" +
  "          if (String(b.scope) === 'products') {\n" +
  "            let pids = b.product_ids; if (!Array.isArray(pids)) pids = (pids != null && pids !== '') ? [pids] : [];\n" +
  "            pids = pids.map(function (x) { return parseInt(x, 10); }).filter(function (x) { return x; });\n" +
  "            for (const pid of pids) await pool.query('INSERT INTO coupon_products(coupon_id, product_id) VALUES($1,$2) ON CONFLICT DO NOTHING', [cid, pid]);\n" +
  "          }\n" +
  "        } catch (e) {}\n" +
  "        res.redirect('/admin/coupons?ok=' + encodeURIComponent('Saved ' + code));";
s = s.replace(SAVE, SAVE2);

fs.writeFileSync(file, s);
console.log('patched: adminCoupons loads products + saves coupon_products scope');
console.log('COUPONADMIN OK');
