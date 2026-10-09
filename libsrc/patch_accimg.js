'use strict';
/* Add product image to the dashboard queries: (SELECT image FROM products WHERE id=orders.product_id) AS image.
   Covers the recent-orders query + the products query + /account/orders + /account/products. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_accimg.js <ROOT>'); process.exit(1); }
const IMG = ', (SELECT image FROM products WHERE id=orders.product_id) AS image';
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

patch('routes/account.js', [
  { // A: recent orders on /account
    name: 'img-recent-orders',
    guard: 'currency, created_at' + IMG + ' FROM orders',
    find: 'status, product_name, plan_label, amount_display, currency, created_at FROM orders',
    replace: 'status, product_name, plan_label, amount_display, currency, created_at' + IMG + ' FROM orders'
  },
  { // C: /account/orders page
    name: 'img-orders-page',
    guard: 'amount_pkr, currency, created_at' + IMG + ' FROM orders',
    find: 'amount_display, amount_pkr, currency, created_at FROM orders',
    replace: 'amount_display, amount_pkr, currency, created_at' + IMG + ' FROM orders'
  },
  { // B: products on /account (LIMIT 24)
    name: 'img-products-dash',
    guard: IMG + " FROM orders WHERE status='delivered' AND (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) ORDER BY id DESC LIMIT 24",
    find: "order_no, product_name, plan_label, created_at FROM orders WHERE status='delivered' AND (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) ORDER BY id DESC LIMIT 24",
    replace: "order_no, product_name, plan_label, created_at" + IMG + " FROM orders WHERE status='delivered' AND (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) ORDER BY id DESC LIMIT 24"
  },
  { // D: /account/products page (LIMIT 60)
    name: 'img-products-page',
    guard: IMG + " FROM orders WHERE status='delivered' AND (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) ORDER BY id DESC LIMIT 60",
    find: "order_no, product_name, plan_label, created_at FROM orders WHERE status='delivered' AND (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) ORDER BY id DESC LIMIT 60",
    replace: "order_no, product_name, plan_label, created_at" + IMG + " FROM orders WHERE status='delivered' AND (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) ORDER BY id DESC LIMIT 60"
  }
]);
console.log('ACCIMG PATCH OK');
