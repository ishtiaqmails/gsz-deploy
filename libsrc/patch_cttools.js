'use strict';
/* Customer Tools pop-up backend: JSON orders feed + claim/replacement submitter.
   Reuses existing /account/order/:no/otp and /subscription for code & renew. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_cttools.js <ROOT>'); process.exit(1); }
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

const ROUTES =
  "  // ---- CUSTOMER TOOLS (pop-up JSON) ----\n" +
  "  router.get('/account/tools/orders', requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer; let rows=[];\n" +
  "    try{ rows=(await pool.query(\"SELECT order_no, product_name, plan_label, status, delivered_credentials FROM orders WHERE (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) AND order_no IS NOT NULL ORDER BY id DESC LIMIT 50\",[c.id,c.email])).rows; }catch(e){}\n" +
  "    res.json({ ok:true, orders: rows.map(function(o){ var done=['delivered','completed','done'].indexOf(String(o.status||'').toLowerCase())>=0; return { order_no:o.order_no, product_name:o.product_name, plan_label:o.plan_label, status:o.status, credentials: done?(o.delivered_credentials||''):'' }; }) });\n" +
  "  });\n" +
  "  router.post('/account/tools/claim', express.json({limit:'16kb'}), requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer; const b = req.body||{};\n" +
  "    const orderNo=String(b.order_no||'').trim(); const reason=String(b.reason||'').trim().slice(0,80); const message=String(b.message||'').trim().slice(0,1000);\n" +
  "    if(!orderNo || !message) return res.json({ ok:false, error:'Please choose an order and describe the issue.' });\n" +
  "    try{\n" +
  "      const o=(await pool.query(\"SELECT id, order_no FROM orders WHERE order_no=$1 AND (customer_id=$2 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($3))) LIMIT 1\",[orderNo,c.id,c.email])).rows[0];\n" +
  "      if(!o) return res.json({ ok:false, error:'We could not match that order to your account.' });\n" +
  "      const ins=await pool.query(\"INSERT INTO order_issues(order_id, customer_id, kind, message, order_no, status, customer_email) VALUES($1,$2,$3,$4,$5,'open',$6) RETURNING id\",[o.id, c.id, (reason||'Replacement'), message, o.order_no, c.email||null]);\n" +
  "      try{ const botapi=require('../lib/botapi'); if(botapi.configured && botapi.configured()){ await botapi.notify({ event:'issue', type:'issue', order_no:o.order_no, issue_id:ins.rows[0].id, message:('['+(reason||'Replacement')+'] '+message).slice(0,500) }); } }catch(e){}\n" +
  "      res.json({ ok:true });\n" +
  "    }catch(e){ res.json({ ok:false, error:'Could not submit. Please try again.' }); }\n" +
  "  });\n\n";

patch('routes/account.js', [
  { name: 'customer-tools-routes', guard: "/account/tools/orders", find: "  // ---- FORGOT / RESET PASSWORD ----", replace: ROUTES + "  // ---- FORGOT / RESET PASSWORD ----" }
]);
console.log('CTTOOLS PATCH OK');
