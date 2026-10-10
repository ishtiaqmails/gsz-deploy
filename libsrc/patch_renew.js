'use strict';
/* Renew popup-checkout backend (added to checkout.js, reusing payMethods/reg/REGIONS/pool):
   - GET /account/tools/pay-methods?amount&region  -> real methods + account details for the modal
   - GET /account/tools/order-status/:no          -> poll a (renew) order's status/credentials
   The renew submit itself reuses the existing POST /checkout (FormData) via its redirect. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_renew.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/checkout.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/account/tools/pay-methods') >= 0) { console.log('skip (already): renew endpoints present'); console.log('RENEW PATCH OK'); process.exit(0); }

const ROUTES =
  "  // ---- RENEW popup-checkout helpers (customer tools) ----\n" +
  "  router.get('/account/tools/pay-methods', async (req, res) => {\n" +
  "    try{\n" +
  "      if(!(req.session && req.session.customer)) return res.status(401).json({ ok:false, auth:false });\n" +
  "      const region = reg(req.query.region); const pkr = Number(req.query.amount||0)||0; const usd = pkr * REGIONS.US.rate;\n" +
  "      const mm = await payMethods(region, pkr, usd);\n" +
  "      res.json({ ok:true, methods:(mm.methods||[]).map(function(m){ return { key:m.key, name:m.name, pay:m.pay, title:m.title||'', account:m.account||'', details:m.details||'', instructions:m.instructions||'', currency:m.currency||'', botAcct:!!m.botAcct }; }) });\n" +
  "    }catch(e){ res.json({ ok:false }); }\n" +
  "  });\n" +
  "  router.get('/account/tools/order-status/:no', async (req, res) => {\n" +
  "    try{\n" +
  "      if(!(req.session && req.session.customer)) return res.status(401).json({ ok:false, auth:false });\n" +
  "      const c = req.session.customer;\n" +
  "      const o = (await pool.query(\"SELECT order_no, status, delivered_credentials FROM orders WHERE order_no=$1 AND (customer_id=$2 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($3))) LIMIT 1\",[req.params.no,c.id,c.email])).rows[0];\n" +
  "      if(!o) return res.json({ ok:false });\n" +
  "      var done=['delivered','completed','done'].indexOf(String(o.status||'').toLowerCase())>=0;\n" +
  "      res.json({ ok:true, status:o.status, done:done, credentials: done?(o.delivered_credentials||''):'' });\n" +
  "    }catch(e){ res.json({ ok:false }); }\n" +
  "  });\n\n";

const anchor = "  // ---- validate a discount code (public; server-computes the subtotal) ----";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: coupon-validate comment not found in checkout.js');
s = s.slice(0, i) + ROUTES + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: added /account/tools/pay-methods + /account/tools/order-status');
console.log('RENEW PATCH OK');
