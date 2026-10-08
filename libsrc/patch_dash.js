'use strict';
/* Dashboard rebuild: replace the thin counts-only dashboard handler in routes/admin.js
   with a command-center query (revenue, orders, open, customers, products, low stock,
   recent orders, waitlist). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_dash.js <ROOT>'); process.exit(1); }
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

const find =
  "    const c = (await pool.query('SELECT count(*)::int n FROM categories')).rows[0].n;\n" +
  "    const p = (await pool.query('SELECT count(*)::int n FROM products')).rows[0].n;\n" +
  "    const b = (await pool.query('SELECT count(*)::int n FROM banners')).rows[0].n;\n" +
  "    res.render('admin/dashboard', { counts: { c, p, b }, flash: req.query.ok || null });";

const replace =
  "    const PAID = \"status IN ('approved','delivering','delivered')\";\n" +
  "    const OPEN = \"status IN ('pending','verifying')\";\n" +
  "    const m = (await pool.query(\n" +
  "      \"SELECT \" +\n" +
  "      \"(SELECT count(*)::int FROM products) AS products, \" +\n" +
  "      \"(SELECT count(*)::int FROM products WHERE active AND NOT hidden) AS products_live, \" +\n" +
  "      \"(SELECT count(*)::int FROM categories) AS categories, \" +\n" +
  "      \"(SELECT count(*)::int FROM customers) AS customers, \" +\n" +
  "      \"(SELECT count(*)::int FROM orders) AS orders_total, \" +\n" +
  "      \"(SELECT count(*)::int FROM orders WHERE created_at::date=current_date) AS orders_today, \" +\n" +
  "      \"(SELECT count(*)::int FROM orders WHERE \" + OPEN + \") AS orders_open, \" +\n" +
  "      \"(SELECT COALESCE(sum(amount_pkr),0) FROM orders WHERE \" + OPEN + \") AS open_value, \" +\n" +
  "      \"(SELECT COALESCE(sum(amount_pkr),0) FROM orders WHERE \" + PAID + \" AND created_at::date=current_date) AS rev_today, \" +\n" +
  "      \"(SELECT COALESCE(sum(amount_pkr),0) FROM orders WHERE \" + PAID + \" AND date_trunc('month',created_at)=date_trunc('month',now())) AS rev_month, \" +\n" +
  "      \"(SELECT count(*)::int FROM restock_waitlist WHERE status='pending') AS waitlist\"\n" +
  "    )).rows[0];\n" +
  "    const recent = (await pool.query(\"SELECT id,order_no,product_name,plan_label,amount_pkr,status,created_at FROM orders ORDER BY created_at DESC LIMIT 6\")).rows;\n" +
  "    const low = (await pool.query(\n" +
  "      \"SELECT pl.id, pr.name AS product_name, pl.label, \" +\n" +
  "      \"(SELECT count(*)::int FROM inventory_items i WHERE i.plan_id=pl.id AND i.status='available') AS avail \" +\n" +
  "      \"FROM product_plans pl JOIN products pr ON pr.id=pl.product_id WHERE pl.source='inventory' \" +\n" +
  "      \"ORDER BY avail ASC, pr.name LIMIT 6\")).rows;\n" +
  "    res.render('admin/dashboard', { m, recent, low, waitlist: m.waitlist, flash: req.query.ok || null });";

patch('routes/admin.js', [{ name: 'dashboard-command-center', guard: 'rev_month', find: find, replace: replace }]);
console.log('DASH PATCH OK');
