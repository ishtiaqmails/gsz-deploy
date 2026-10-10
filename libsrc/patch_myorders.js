'use strict';
/* My Orders: enrich /account/tools/orders with computed expiry, status, days-left, warranty
   (from plan duration + products/product_plans/bot_products.warranty). Newest first. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_myorders.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

const OLD =
  "  router.get('/account/tools/orders', requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer; let rows=[];\n" +
  "    try{ rows=(await pool.query(\"SELECT order_no, product_name, plan_label, status, delivered_credentials FROM orders WHERE (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) AND order_no IS NOT NULL ORDER BY id DESC LIMIT 50\",[c.id,c.email])).rows; }catch(e){}\n" +
  "    res.json({ ok:true, orders: rows.map(function(o){ var done=['delivered','completed','done'].indexOf(String(o.status||'').toLowerCase())>=0; return { order_no:o.order_no, product_name:o.product_name, plan_label:o.plan_label, status:o.status, credentials: done?(o.delivered_credentials||''):'' }; }) });\n" +
  "  });\n";

const NEW =
  "  function _durDays(label){ var x=String(label||'').toLowerCase(); if(/life ?time|forever|permanent/.test(x)) return null; var m=x.match(/(\\d+)\\s*(day|week|month|year)/); if(m){ var n=parseInt(m[1],10)||1, u=m[2]; return u==='day'?n:(u==='week'?n*7:(u==='month'?n*30:n*365)); } if(/year|annual/.test(x)) return 365; if(/month/.test(x)) return 30; if(/week/.test(x)) return 7; return null; }\n" +
  "  function _digits(v){ var m=String(v==null?'':v).match(/\\d+/); return m?parseInt(m[0],10):0; }\n" +
  "  router.get('/account/tools/orders', requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer; let rows=[];\n" +
  "    try{ rows=(await pool.query(\"SELECT o.order_no, o.product_name, o.plan_label, o.status, o.delivered_credentials, o.created_at, o.product_id, o.bot_sku, COALESCE(pp.warranty, p.warranty) AS warranty, bp.warranty_days AS bot_warranty_days FROM orders o LEFT JOIN products p ON p.id=o.product_id LEFT JOIN product_plans pp ON pp.product_id=o.product_id AND pp.label=o.plan_label LEFT JOIN bot_products bp ON bp.sku=o.bot_sku WHERE (o.customer_id=$1 OR (o.customer_id IS NULL AND o.email IS NOT NULL AND lower(o.email)=lower($2))) AND o.order_no IS NOT NULL ORDER BY o.id DESC LIMIT 60\",[c.id,c.email])).rows; }catch(e){}\n" +
  "    var now=Date.now();\n" +
  "    res.json({ ok:true, orders: rows.map(function(o){\n" +
  "      var done=['delivered','completed','done'].indexOf(String(o.status||'').toLowerCase())>=0;\n" +
  "      var pur=o.created_at?new Date(o.created_at).getTime():null;\n" +
  "      var dur=_durDays(o.plan_label);\n" +
  "      var exp=(pur&&dur)?(pur+dur*86400000):null;\n" +
  "      var daysLeft=exp?Math.ceil((exp-now)/86400000):null;\n" +
  "      var sub=!done?'pending':(exp==null?'active':(exp>now?(daysLeft<=3?'expiring':'active'):'expired'));\n" +
  "      var warrD=_digits(o.warranty)||(o.bot_warranty_days||0);\n" +
  "      var wExp=(pur&&warrD)?(pur+warrD*86400000):null;\n" +
  "      return { order_no:o.order_no, product_name:o.product_name, plan_label:o.plan_label||'', status:o.status,\n" +
  "        credentials: done?(o.delivered_credentials||''):'',\n" +
  "        purchased:o.created_at, expiry: exp?new Date(exp).toISOString():null, days_left:daysLeft,\n" +
  "        sub_status:sub, warranty_days: warrD||null, under_warranty: !!(done && wExp && wExp>now) };\n" +
  "    }) });\n" +
  "  });\n";

if (s.indexOf('_durDays') >= 0) { console.log('skip (already): My Orders endpoint enriched'); }
else {
  const i = s.indexOf(OLD);
  if (i < 0) throw new Error('ANCHOR MISS: original /account/tools/orders route not found');
  s = s.slice(0, i) + NEW + s.slice(i + OLD.length);
  fs.writeFileSync(file, s);
  console.log('patched: enriched /account/tools/orders (expiry/status/days-left/warranty)');
}
console.log('MYORDERS PATCH OK');
