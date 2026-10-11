'use strict';
/* One-click Most Selling toggle from the products list (POST /admin/products/:id/most-selling). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_mostselling.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/adminCatalog.js');
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf("/products/:id/most-selling") >= 0) { console.log('most-selling route present (skip)'); }
else {
  const ANCH = "  router.post('/products/:id/trending', auth, async (req, res) => {";
  const NEW = "  router.post('/products/:id/most-selling', auth, async (req, res) => {\n" +
    "    await pool.query('UPDATE products SET most_selling = NOT most_selling WHERE id=$1', [req.params.id]);\n" +
    "    res.redirect('/admin/products?ok=Most+Selling+updated');\n" +
    "  });\n";
  if (s.indexOf(ANCH) >= 0) { s = s.replace(ANCH, NEW + ANCH); fs.writeFileSync(file, s); console.log('most-selling route added'); }
  else { console.log('anchor missing (skip)'); }
}
console.log('MOSTSELLING OK');
