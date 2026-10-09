'use strict';
/* Wire the dark dashboard: extend GET /account with products/tickets/spend/payments/profile
   data, and add GET /account/orders + /account/products pages. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_accdash.js <ROOT>'); process.exit(1); }
function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    const first = s.indexOf(e.find);
    if (first < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
    if (s.indexOf(e.find, first + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
    s = s.slice(0, first) + e.replace + s.slice(first + e.find.length);
    console.log('patched: ' + rel + ' :: ' + e.name);
  }
  fs.writeFileSync(file, s);
}

const RENDER = "    res.render('account/dashboard', Object.assign(await shell(), { title: 'My account', c, ok: req.query.ok || null, wa, orders, announcements, stats, qa }));";
const DATA =
  "    // --- dark dashboard data ---\n" +
  "    let activeProducts=0, ticketsOpen=0, totalSpent=0, products=[], payMethods=[], memberSince=null, refCode='', location='';\n" +
  "    try{ activeProducts=(await pool.query(\"SELECT count(DISTINCT product_id)::int n FROM orders WHERE status='delivered' AND (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2)))\",[c.id,c.email])).rows[0].n; }catch(e){}\n" +
  "    try{ ticketsOpen=(await pool.query(\"SELECT count(*)::int n FROM order_issues WHERE (customer_id=$1 OR (customer_email IS NOT NULL AND lower(customer_email)=lower($2))) AND resolved_at IS NULL\",[c.id,c.email])).rows[0].n; }catch(e){}\n" +
  "    try{ totalSpent=Number((await pool.query(\"SELECT COALESCE(SUM(amount_pkr),0) s FROM orders WHERE status IN ('delivered','paid') AND (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2)))\",[c.id,c.email])).rows[0].s)||0; }catch(e){}\n" +
  "    try{ products=(await pool.query(\"SELECT order_no, product_name, plan_label, created_at FROM orders WHERE status='delivered' AND (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) ORDER BY id DESC LIMIT 24\",[c.id,c.email])).rows; }catch(e){}\n" +
  "    try{ payMethods=(await pool.query(\"SELECT name FROM payment_methods ORDER BY id LIMIT 8\")).rows; }catch(e){}\n" +
  "    try{ const cf=(await pool.query('SELECT created_at, ref_code FROM customers WHERE id=$1',[c.id])).rows[0]; if(cf){ memberSince=cf.created_at; refCode=cf.ref_code||''; } }catch(e){}\n" +
  "    try{ const lr=(await pool.query(\"SELECT region FROM orders WHERE (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) AND region IS NOT NULL ORDER BY id DESC LIMIT 1\",[c.id,c.email])).rows[0]; if(lr&&lr.region){ location=String(lr.region).toUpperCase()==='PK'?'Pakistan':String(lr.region).toUpperCase(); } }catch(e){}\n" +
  "    res.render('account/dashboard', Object.assign(await shell(), { title: 'Dashboard', c, ok: req.query.ok || null, wa, orders, announcements, stats, qa, activeProducts, ticketsOpen, totalSpent, products, payMethods, memberSince, refCode, location }));";

const ROUTES =
  "  // ---- MY ORDERS (dashboard) ----\n" +
  "  router.get('/account/orders', requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer; let orders=[];\n" +
  "    try{ orders=(await pool.query(\"SELECT id, order_no, status, product_name, plan_label, amount_display, amount_pkr, currency, created_at FROM orders WHERE customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2)) ORDER BY id DESC LIMIT 100\",[c.id,c.email])).rows; }catch(e){}\n" +
  "    res.render('account/orders', Object.assign(await shell(), { title:'My Orders', c, orders }));\n" +
  "  });\n" +
  "  // ---- MY PRODUCTS (dashboard) ----\n" +
  "  router.get('/account/products', requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer; let products=[];\n" +
  "    try{ products=(await pool.query(\"SELECT order_no, product_name, plan_label, created_at FROM orders WHERE status='delivered' AND (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) ORDER BY id DESC LIMIT 60\",[c.id,c.email])).rows; }catch(e){}\n" +
  "    res.render('account/products', Object.assign(await shell(), { title:'My Products', c, products }));\n" +
  "  });\n\n";

patch('routes/account.js', [
  { name: 'dashboard-data', guard: 'dark dashboard data', find: RENDER, replace: DATA },
  { name: 'orders-products-routes', guard: "router.get('/account/orders'", find: "  // ---- FORGOT / RESET PASSWORD ----", replace: ROUTES + "  // ---- FORGOT / RESET PASSWORD ----" }
]);
console.log('ACCDASH PATCH OK');
