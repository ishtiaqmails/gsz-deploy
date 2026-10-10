'use strict';
/* Renew flow backend (Hub) — the front-end (customer_tools.ejs renew/coStep) already calls these;
   they were never built. Renew stays fully in-model (pop-up/sheet), pays on-site via the existing
   /checkout (which already handles b.renew -> fields.renew_of), same plans, no coupon.
   - GET /account/order/:no/subscription -> { ok, active, renewable, slug, options:[{idx,label,price_pkr}], expires_at, days_left }
   - GET /account/tools/pay-methods?amount= -> { ok, methods:[{key,name,pay,title,account,details,instructions}] }
   Owner-gated. options.idx = 0-based index into product_plans (sort,id) — matches how /checkout resolves b.plan.
   'renewable' respects products.renewable (added by the Deploy D migration; defaults true).
   Idempotent: skips if present. Inserts before the FORGOT anchor. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_renewflow.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf("/account/order/:no/subscription") >= 0) { console.log('skip (already): renew flow present'); console.log('RENEWFLOW PATCH OK'); process.exit(0); }

const ROUTES =
"  // ---- RENEW (Hub): subscription check + pay methods (on-site, same plans) ----\n" +
"  function _rfBot(){ try{ return require('../lib/botapi'); }catch(e){ return null; } }\n" +
"  async function _rfWa(c){ try{ const L=(await pool.query(\"SELECT i.current_phone_e164 FROM customer_whatsapp_links l JOIN whatsapp_identities i ON i.id=l.whatsapp_identity_id WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1\",[c.id])).rows[0]; return (L&&L.current_phone_e164)?String(L.current_phone_e164).replace(/[^0-9]/g,''):''; }catch(e){ return ''; } }\n" +
"  router.get('/account/order/:no/subscription', requireLogin, async (req, res) => {\n" +
"    const c=req.session.customer; let o=null;\n" +
"    try{ o=(await pool.query(\"SELECT order_no, product_id FROM orders WHERE order_no=$1 AND (customer_id=$2 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($3))) LIMIT 1\",[String(req.params.no||''),c.id,c.email])).rows[0]||null; }catch(e){}\n" +
"    if(!o) return res.json({ ok:false, reason:'not_owner' });\n" +
"    let sub=null; const bot=_rfBot();\n" +
"    if(bot && bot.configured && bot.configured() && typeof bot.getSubscription==='function'){ try{ sub=await bot.getSubscription(o.order_no, await _rfWa(c)); }catch(e){} }\n" +
"    const active=!!(sub && sub.ok && sub.active);\n" +
"    const expires_at=(sub && sub.expires_at) ? sub.expires_at : null;\n" +
"    const days_left=expires_at ? Math.ceil((new Date(expires_at).getTime()-Date.now())/86400000) : null;\n" +
"    let slug=null, options=[], renewable=false;\n" +
"    if(o.product_id){\n" +
"      let p=null; try{ p=(await pool.query(\"SELECT slug, active, renewable FROM products WHERE id=$1\",[o.product_id])).rows[0]; }catch(e){ try{ p=(await pool.query(\"SELECT slug, active FROM products WHERE id=$1\",[o.product_id])).rows[0]; }catch(e2){} }\n" +
"      if(p && p.active){ slug=p.slug;\n" +
"        let plans=[]; try{ plans=(await pool.query(\"SELECT label, price_pkr FROM product_plans WHERE product_id=$1 ORDER BY sort,id\",[o.product_id])).rows; }catch(e){}\n" +
"        options=plans.map(function(pl,idx){ return { idx:idx, label:pl.label, price_pkr: Number(pl.price_pkr)||0 }; });\n" +
"        const flag=(p.renewable===undefined || p.renewable===null) ? true : !!p.renewable;\n" +
"        renewable = !!(active && slug && options.length && flag);\n" +
"      }\n" +
"    }\n" +
"    res.json({ ok:true, active, renewable, slug, options, expires_at, days_left });\n" +
"  });\n" +
"  router.get('/account/tools/pay-methods', requireLogin, async (req, res) => {\n" +
"    const amount=Math.max(0, Math.round(Number(req.query.amount)||0));\n" +
"    const fmtPkr=function(n){ return 'Rs ' + Math.round(n).toLocaleString('en-US'); };\n" +
"    let methods=[]; const bot=_rfBot();\n" +
"    try{\n" +
"      if(bot && bot.configured && bot.configured()){\n" +
"        const accts=await bot.getPayAccounts();\n" +
"        (accts||[]).forEach(function(a){ const cur=String(a.currency||'PKR').toUpperCase(); if(cur!=='PKR') return; /* region PK: pay in PKR */\n" +
"          methods.push({ key:a.key, name:a.label||a.method||a.name||a.key, pay:fmtPkr(amount), title:a.title||'', account:a.account||'', details:a.details||'', instructions:a.instructions||'' }); });\n" +
"      }\n" +
"    }catch(e){}\n" +
"    if(!methods.length){ try{ const rows=(await pool.query(\"SELECT key, name, details, instructions, currency FROM payment_methods WHERE COALESCE(currency,'PKR')='PKR' ORDER BY id LIMIT 12\")).rows; methods=rows.map(function(m){ return { key:m.key, name:m.name, pay:fmtPkr(amount), title:'', account:'', details:m.details||'', instructions:m.instructions||'' }; }); }catch(e){} }\n" +
"    res.json({ ok:true, methods });\n" +
"  });\n\n";

const anchor = "  // ---- FORGOT / RESET PASSWORD ----";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: FORGOT/RESET comment not found in account.js');
s = s.slice(0, i) + ROUTES + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: added /account/order/:no/subscription + /account/tools/pay-methods');
console.log('RENEWFLOW PATCH OK');
