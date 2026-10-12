'use strict';
/* GSZ (site) routes for the Hub "Renew IPTV Subscription" flow:
   - GET  /account/tools/iptv/options  -> IPTV services (category 'iptv') with their bot sku + renewal plans
   - POST /account/tools/iptv/lookup   -> verified-WhatsApp gated; bridges to gsz-api POST /api/iptv-lookup
                                          (read-only line lookup: current expiry; no credits)
   Inserts before the FORGOT/RESET anchor in routes/account.js. Idempotent; aborts if anchor moved. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_iptvhub.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf("/account/tools/iptv/lookup") >= 0) { console.log('skip (already): iptv hub routes present'); console.log('IPTVHUB PATCH OK'); process.exit(0); }

const ANCHOR = "  // ---- FORGOT / RESET PASSWORD ----";
if (s.indexOf(ANCHOR) < 0) throw new Error('ANCHOR MISS: FORGOT/RESET comment not found in account.js');

const ROUTES =
"  // ---- IPTV RENEW (Hub): service options + read-only line lookup (no credits) ----\n" +
"  const _ivBot = () => { try { return require('../lib/botapi'); } catch(e){ return null; } };\n" +
"  async function _ivWaVerified(c){ try{ const r=await pool.query(\"SELECT 1 FROM customer_whatsapp_links l WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1\",[c.id]); return r.rows.length>0; }catch(e){ return false; } }\n" +
"  router.get('/account/tools/iptv/options', requireLogin, async (req, res) => {\n" +
"    try{\n" +
"      const prods=(await pool.query(\"SELECT p.id, p.name, p.slug, (SELECT pp.bot_sku FROM product_plans pp WHERE pp.product_id=p.id AND pp.source='bot' AND pp.bot_sku IS NOT NULL ORDER BY pp.sort,pp.id LIMIT 1) AS bot_sku FROM products p JOIN categories c ON c.id=p.category_id WHERE c.slug='iptv' AND p.active AND NOT p.hidden ORDER BY p.name\")).rows;\n" +
"      const out=[];\n" +
"      for(const p of prods){ if(!p.bot_sku) continue;\n" +
"        let plans=[]; try{ plans=(await pool.query(\"SELECT id, label, price_pkr, bot_plan_key FROM product_plans WHERE product_id=$1 AND source='bot' AND bot_plan_key IS NOT NULL ORDER BY sort,id\",[p.id])).rows; }catch(e){}\n" +
"        if(!plans.length) continue;\n" +
"        out.push({ id:p.id, name:p.name, slug:p.slug, sku:p.bot_sku, plans:plans.map(function(pl){ return { id:pl.id, label:pl.label, price_pkr:Number(pl.price_pkr)||0, plan_key:pl.bot_plan_key }; }) });\n" +
"      }\n" +
"      res.json({ ok:true, services: out });\n" +
"    }catch(e){ res.json({ ok:false, services:[] }); }\n" +
"  });\n" +
"  router.post('/account/tools/iptv/lookup', requireLogin, async (req, res) => {\n" +
"    const c=req.session.customer;\n" +
"    if(!(await _ivWaVerified(c))) return res.json({ ok:false, reason:'wa_unverified' });\n" +
"    const sku=String((req.body&&req.body.sku)||'').trim();\n" +
"    const raw=String((req.body&&req.body.raw)||'');\n" +
"    const username=String((req.body&&req.body.username)||'').trim();\n" +
"    const password=String((req.body&&req.body.password)||'');\n" +
"    if(!sku) return res.json({ ok:false, reason:'no_service' });\n" +
"    const bot=_ivBot(); if(!bot || typeof bot.iptvLookup!=='function') return res.json({ ok:false, reason:'unavailable' });\n" +
"    try{ const r=await bot.iptvLookup({ sku:sku, raw:raw, username:username, password:password }); return res.json(r||{ ok:false, reason:'unavailable' }); }\n" +
"    catch(e){ return res.json({ ok:false, reason:'unavailable' }); }\n" +
"  });\n" +
"  // ---- END IPTV RENEW (Hub) ----\n\n";

const i = s.indexOf(ANCHOR);
s = s.slice(0, i) + ROUTES + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: /account/tools/iptv/options + /lookup');
console.log('IPTVHUB PATCH OK');
