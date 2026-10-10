'use strict';
/* Get Access (Hub) backend — the front-end already calls these, they were never built:
   - POST /account/order/:no/otp    -> retrieve a sign-in OTP via the bot
   - POST /account/order/:no/link   -> retrieve a login link via the bot
   - GET  /account/tools/order-status/:no -> poll a (renewal) order's status
   Owner-gated. Responses normalised to what customer_tools.ejs expects:
     success: { ok:true, value:<code|url>, kind?:'link', used?, limit? }
     pending: { ok:false, reason:'waiting' }   (the UI auto-retries)
   The '/account/tools/household/:no' endpoint already exists; it just needed
   botapi.updateHousehold (see patch_botapi2.js).
   Idempotent: skips if already present. Inserts before the FORGOT anchor. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_getaccess.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf("/account/order/:no/otp") >= 0) { console.log('skip (already): get-access endpoints present'); console.log('GETACCESS PATCH OK'); process.exit(0); }

const ROUTES =
"  // ---- GET ACCESS (Hub): OTP / login link retrieve + order status ----\n" +
"  async function _gaOwns(c, no){ try{ return (await pool.query(\"SELECT order_no FROM orders WHERE order_no=$1 AND (customer_id=$2 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($3))) LIMIT 1\",[no,c.id,c.email])).rows[0]||null; }catch(e){ return null; } }\n" +
"  async function _gaWa(c){ try{ const L=(await pool.query(\"SELECT i.current_phone_e164 FROM customer_whatsapp_links l JOIN whatsapp_identities i ON i.id=l.whatsapp_identity_id WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1\",[c.id])).rows[0]; return (L&&L.current_phone_e164)?String(L.current_phone_e164).replace(/[^0-9]/g,''):''; }catch(e){ return ''; } }\n" +
"  function _gaBot(){ try{ return require('../lib/botapi'); }catch(e){ return null; } }\n" +
"  function _gaNorm(r, forceLink){ r=r||{}; const val=r.value||r.code||r.otp||r.link||r.url||''; if((r.ok!==false)&&val){ const out={ ok:true, value:String(val) }; if(forceLink||r.kind==='link'||/^https?:\\/\\//i.test(String(val))) out.kind='link'; if(r.used!=null) out.used=r.used; if(r.limit!=null) out.limit=r.limit; return out; } return { ok:false, reason:(r.reason||'waiting'), used:r.used, limit:r.limit }; }\n" +
"  router.post('/account/order/:no/otp', requireLogin, async (req, res) => {\n" +
"    const c=req.session.customer; const o=await _gaOwns(c, String(req.params.no||'')); if(!o) return res.json({ ok:false, reason:'not_owner' });\n" +
"    const bot=_gaBot(); if(!(bot && bot.configured && bot.configured() && typeof bot.retrieveOtp==='function')) return res.json({ ok:false, reason:'not_supported' });\n" +
"    try{ const r=await bot.retrieveOtp(o.order_no, await _gaWa(c)); return res.json(_gaNorm(r, false)); }catch(e){ return res.json({ ok:false, reason:'waiting' }); }\n" +
"  });\n" +
"  router.post('/account/order/:no/link', requireLogin, async (req, res) => {\n" +
"    const c=req.session.customer; const o=await _gaOwns(c, String(req.params.no||'')); if(!o) return res.json({ ok:false, reason:'not_owner' });\n" +
"    const bot=_gaBot(); if(!(bot && bot.configured && bot.configured() && typeof bot.retrieveLink==='function')) return res.json({ ok:false, reason:'not_supported' });\n" +
"    try{ const r=await bot.retrieveLink(o.order_no, await _gaWa(c)); return res.json(_gaNorm(r, true)); }catch(e){ return res.json({ ok:false, reason:'waiting' }); }\n" +
"  });\n" +
"  router.get('/account/tools/order-status/:no', requireLogin, async (req, res) => {\n" +
"    const c=req.session.customer; const o=await _gaOwns(c, String(req.params.no||'')); if(!o) return res.json({ ok:false, reason:'not_owner' });\n" +
"    const bot=_gaBot(); if(!(bot && typeof bot.orderStatus==='function')) return res.json({ ok:false });\n" +
"    try{ const r=await bot.orderStatus(o.order_no); return res.json(Object.assign({ ok:true }, r||{})); }catch(e){ return res.json({ ok:false, reason:'waiting' }); }\n" +
"  });\n\n";

const anchor = "  // ---- FORGOT / RESET PASSWORD ----";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: FORGOT/RESET comment not found in account.js');
s = s.slice(0, i) + ROUTES + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: added /account/order/:no/otp, /link, /account/tools/order-status/:no');
console.log('GETACCESS PATCH OK');
