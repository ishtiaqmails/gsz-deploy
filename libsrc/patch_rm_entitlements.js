'use strict';
/* Clean-up: remove the now-unused /account/tools/entitlements route from routes/account.js
   (Quick Access is no longer product-aware). Reconstructs the exact block that
   patch_entitlements.js injected and removes it. Idempotent; no-op if already gone. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_rm_entitlements.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

const OWN = "(o.customer_id=$1 OR (o.customer_id IS NULL AND o.email IS NOT NULL AND lower(o.email)=lower($2)))";
const OWN2 = "(customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2)))";
const ROUTE =
  "  // ---- QUICK ACCESS ENTITLEMENTS (which tools to show a customer) ----\n" +
  "  router.get('/account/tools/entitlements', async (req, res) => {\n" +
  "    const c = req.session && req.session.customer;\n" +
  "    if (!c) return res.json({ ok:true, loggedIn:false, orders:false, access:false, renewable:false });\n" +
  "    let orders=false, renewable=false, access=false;\n" +
  "    try{ orders = (await pool.query(\"SELECT EXISTS(SELECT 1 FROM orders WHERE " + OWN2 + " AND order_no IS NOT NULL) e\",[c.id,c.email])).rows[0].e; }catch(e){}\n" +
  "    try{ renewable = (await pool.query(\"SELECT EXISTS(SELECT 1 FROM orders o JOIN products p ON p.id=o.product_id WHERE " + OWN + " AND o.order_no IS NOT NULL AND COALESCE(p.renewable,false)=true) e\",[c.id,c.email])).rows[0].e; }catch(e){}\n" +
  "    try{ const rows=(await pool.query(\"SELECT bp.retrieve FROM orders o LEFT JOIN product_plans pp ON pp.product_id=o.product_id AND pp.label=o.plan_label LEFT JOIN bot_products bp ON bp.sku=COALESCE(pp.bot_sku, o.bot_sku) WHERE " + OWN + " AND o.order_no IS NOT NULL AND lower(o.status) IN ('delivered','completed','done') LIMIT 60\",[c.id,c.email])).rows;\n" +
  "      access = rows.some(function(o){ var r=o.retrieve||{}; if(typeof r==='string'){ try{ r=JSON.parse(r); }catch(e){ r={}; } } return ['otp','link','household'].some(function(k){ return r[k] && r[k].enabled; }); }); }catch(e){}\n" +
  "    res.json({ ok:true, loggedIn:true, orders:!!orders, access:!!access, renewable:!!renewable });\n" +
  "  });\n\n";

if (s.indexOf("'/account/tools/entitlements'") < 0) { console.log('entitlements route: already gone (skip)'); console.log('RM_ENTITLEMENTS OK'); process.exit(0); }
if (s.indexOf(ROUTE) < 0) { console.error('PATCH FAILED — entitlements block not found verbatim (do not force)'); process.exit(2); }
s = s.split(ROUTE).join('');
fs.writeFileSync(file, s);
console.log('entitlements route: removed');
console.log('RM_ENTITLEMENTS OK');
