'use strict';
/* #75 — make /api/announcements product-aware for logged-in customers.
   Logged out: global only (unchanged). Logged in: global + announcements
   targeted at products the customer has ordered. Richer payload (date, product).
   routes/account.js. Idempotent; aborts if the anchor moved. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_annfeed.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

const GUARD = "/*annFeedPA*/";
if (s.indexOf(GUARD) >= 0) { console.log('skip (already): announcements product-aware'); process.exit(0); }

const FIND =
"  router.get('/api/announcements', async (req, res) => {\n" +
"    let rows=[];\n" +
"    try{ rows=(await pool.query(\"SELECT id, title, body, kind, coupon_code FROM announcements WHERE target_product_id IS NULL ORDER BY id DESC LIMIT 8\")).rows; }catch(e){}\n" +
"    res.json({ ok:true, items: rows.map(function(a){ return { id:a.id, title:a.title, body:a.body, kind:a.kind||'', coupon:a.coupon_code||'' }; }) });\n" +
"  });";

const REPL =
"  router.get('/api/announcements', async (req, res) => { /*annFeedPA*/\n" +
"    let rows=[]; const _c=(req.session&&req.session.customer)?req.session.customer:null;\n" +
"    try{\n" +
"      if(_c){ rows=(await pool.query(\"SELECT a.id, a.title, a.body, a.kind, a.coupon_code, a.created_at, p.name AS product_name FROM announcements a LEFT JOIN products p ON p.id=a.target_product_id WHERE a.target_product_id IS NULL OR a.target_product_id IN (SELECT DISTINCT product_id FROM orders WHERE (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) AND product_id IS NOT NULL) ORDER BY a.id DESC LIMIT 20\",[_c.id,_c.email])).rows; }\n" +
"      else { rows=(await pool.query(\"SELECT id, title, body, kind, coupon_code, created_at, NULL AS product_name FROM announcements WHERE target_product_id IS NULL ORDER BY id DESC LIMIT 8\")).rows; }\n" +
"    }catch(e){}\n" +
"    res.json({ ok:true, items: rows.map(function(a){ return { id:a.id, title:a.title, body:a.body, kind:a.kind||'', coupon:a.coupon_code||'', created_at:a.created_at||null, product:a.product_name||'' }; }) });\n" +
"  });";

const i = s.indexOf(FIND);
if (i < 0) throw new Error('ANCHOR MISS: /api/announcements route');
if (s.indexOf(FIND, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE');
s = s.slice(0, i) + REPL + s.slice(i + FIND.length);
fs.writeFileSync(file, s);
console.log('ANNOUNCEMENTS PRODUCT-AWARE PATCH OK');
