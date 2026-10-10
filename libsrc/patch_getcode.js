'use strict';
/* Get Code: self-aware eligibility feed (per-plan retrieve caps: otp/link/household) + guarded
   household route (lights up when the bot exposes updateHousehold). otp/link reuse existing routes. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_getcode.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/account/tools/retrievable') >= 0) { console.log('skip (already): Get Code routes present'); console.log('GETCODE PATCH OK'); process.exit(0); }

const ROUTES =
  "  // ---- GET CODE (self-aware retrieve capabilities) ----\n" +
  "  router.get('/account/tools/retrievable', requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer; let rows=[];\n" +
  "    try{ rows=(await pool.query(\"SELECT o.order_no, o.product_name, o.plan_label, bp.retrieve FROM orders o LEFT JOIN product_plans pp ON pp.product_id=o.product_id AND pp.label=o.plan_label LEFT JOIN bot_products bp ON bp.sku=COALESCE(pp.bot_sku, o.bot_sku) WHERE (o.customer_id=$1 OR (o.customer_id IS NULL AND o.email IS NOT NULL AND lower(o.email)=lower($2))) AND o.order_no IS NOT NULL AND lower(o.status) IN ('delivered','completed','done') ORDER BY o.id DESC LIMIT 60\",[c.id,c.email])).rows; }catch(e){}\n" +
  "    const out=[];\n" +
  "    rows.forEach(function(o){ var r=o.retrieve||{}; if(typeof r==='string'){ try{ r=JSON.parse(r); }catch(e){ r={}; } }\n" +
  "      var caps={}; ['otp','link','household'].forEach(function(k){ if(r[k] && r[k].enabled){ caps[k]={ enabled:true, limit:(r[k].unlimited?null:(r[k].limit||null)) }; } });\n" +
  "      if(Object.keys(caps).length) out.push({ order_no:o.order_no, product_name:o.product_name, plan_label:o.plan_label||'', caps:caps });\n" +
  "    });\n" +
  "    res.json({ ok:true, orders: out });\n" +
  "  });\n" +
  "  router.post('/account/tools/household/:no', requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer;\n" +
  "    try{\n" +
  "      const o=(await pool.query(\"SELECT order_no FROM orders WHERE order_no=$1 AND (customer_id=$2 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($3))) LIMIT 1\",[req.params.no,c.id,c.email])).rows[0];\n" +
  "      if(!o) return res.json({ ok:false, reason:'not_owner' });\n" +
  "      let botapi=null; try{ botapi=require('../lib/botapi'); }catch(e){}\n" +
  "      if(!(botapi && typeof botapi.updateHousehold==='function')) return res.json({ ok:false, reason:'not_supported' });\n" +
  "      let wa=''; try{ const L=(await pool.query(\"SELECT i.current_phone_e164 FROM customer_whatsapp_links l JOIN whatsapp_identities i ON i.id=l.whatsapp_identity_id WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1\",[c.id])).rows[0]; if(L&&L.current_phone_e164) wa=String(L.current_phone_e164).replace(/[^0-9]/g,''); }catch(e){}\n" +
  "      const r=await botapi.updateHousehold(o.order_no, wa);\n" +
  "      return res.json(r||{ ok:false, reason:'error' });\n" +
  "    }catch(e){ return res.json({ ok:false, reason:'error' }); }\n" +
  "  });\n\n";

const anchor = "  // ---- FORGOT / RESET PASSWORD ----";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: FORGOT marker not found');
s = s.slice(0, i) + ROUTES + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: added /account/tools/retrievable + /account/tools/household/:no');
console.log('GETCODE PATCH OK');
