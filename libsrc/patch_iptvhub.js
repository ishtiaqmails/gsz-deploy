'use strict';
/* GSZ (site) routes for the Hub "Renew IPTV Subscription" flow:
   - GET  /account/tools/iptv/options  -> IPTV services (category 'iptv') with their bot sku + renewal plans
   - POST /account/tools/iptv/lookup   -> verified-WhatsApp gated; bridges to gsz-api POST /api/iptv-lookup
                                          (read-only line lookup: current expiry; no credits)
   The POST route carries its own JSON + urlencoded body parsers (routes here aren't globally parsed).
   Re-appliable: removes its own prior block then reinserts before the FORGOT/RESET anchor. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_iptvhub.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

const START = "  // ---- IPTV RENEW (Hub): service options + read-only line lookup (no credits) ----\n";
const END   = "  // ---- END IPTV RENEW (Hub) ----\n\n";
const ANCHOR = "  // ---- FORGOT / RESET PASSWORD ----";

const ROUTES =
START +
"  const _ivBot = () => { try { return require('../lib/botapi'); } catch(e){ return null; } };\n" +
"  const _ivJson = require('express').json();\n" +
"  const _ivForm = require('express').urlencoded({ extended:true });\n" +
"  async function _ivWaVerified(c){ try{ const r=await pool.query(\"SELECT 1 FROM customer_whatsapp_links l WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1\",[c.id]); return r.rows.length>0; }catch(e){ return false; } }\n" +
"  router.get('/account/tools/iptv/options', requireLogin, async (req, res) => {\n" +
"    try{\n" +
"      const prods=(await pool.query(\"SELECT p.id, p.name, p.slug, (SELECT pp.bot_sku FROM product_plans pp WHERE pp.product_id=p.id AND pp.source='bot' AND pp.bot_sku IS NOT NULL ORDER BY pp.sort,pp.id LIMIT 1) AS bot_sku FROM products p JOIN categories c ON c.id=p.category_id WHERE c.slug='iptv' AND p.active AND NOT p.hidden ORDER BY p.name\")).rows;\n" +
"      const out=[];\n" +
"      for(const p of prods){ if(!p.bot_sku) continue;\n" +
"        let allPlans=[]; try{ allPlans=(await pool.query(\"SELECT id, label, price_pkr, bot_plan_key, source, version_labels FROM product_plans WHERE product_id=$1 ORDER BY sort,id\",[p.id])).rows; }catch(e){}\n" +
"        let plans=[]; allPlans.forEach(function(pl,idx){ if(pl.source==='bot' && pl.bot_plan_key) plans.push({ id:pl.id, idx:idx, label:pl.label, price_pkr:Number(pl.price_pkr)||0, plan_key:pl.bot_plan_key }); });\n" +
"        if(!plans.length) continue;\n" +
"        let relabels=[]; for(const pl of allPlans){ let vl=pl.version_labels; if(typeof vl==='string'){ try{ vl=JSON.parse(vl); }catch(e){ vl=null; } } if(Array.isArray(vl) && vl.length){ relabels=vl.filter(function(v){return v&&v.key;}).map(function(v){return { key:String(v.key), label:String(v.label||v.key) };}); break; } }\n" +
"        out.push({ id:p.id, name:p.name, slug:p.slug, sku:p.bot_sku, version_labels:relabels, plans:plans });\n" +
"      }\n" +
"      res.json({ ok:true, services: out });\n" +
"    }catch(e){ res.json({ ok:false, services:[] }); }\n" +
"  });\n" +
"  router.post('/account/tools/iptv/lookup', requireLogin, _ivJson, _ivForm, async (req, res) => {\n" +
"    const c=req.session.customer;\n" +
"    if(!(await _ivWaVerified(c))) return res.json({ ok:false, reason:'wa_unverified' });\n" +
"    const b=req.body||{};\n" +
"    const sku=String(b.sku||'').trim();\n" +
"    const raw=String(b.raw||'');\n" +
"    let username=String(b.username||'').trim();\n" +
"    const password=String(b.password||'');\n" +
"    if(!username){ const t=raw.trim(); if(t && !/[\\s:=@]/.test(t)) username=t; }\n" +  // a bare single token is the username
"    if(!sku) return res.json({ ok:false, reason:'no_service' });\n" +
"    const bot=_ivBot(); if(!bot || typeof bot.iptvLookup!=='function') return res.json({ ok:false, reason:'unavailable' });\n" +
"    try{ const r=await bot.iptvLookup({ sku:sku, raw:raw, username:username, password:password }); return res.json(r||{ ok:false, reason:'unavailable' }); }\n" +
"    catch(e){ return res.json({ ok:false, reason:'unavailable', detail:String((e&&e.message)||e).slice(0,160) }); }\n" +
"  });\n" +
"  router.get('/account/tools/iptv/lookup-status/:id', requireLogin, async (req, res) => {\n" +
"    const bot=_ivBot(); if(!bot || typeof bot.iptvLookupStatus!=='function') return res.json({ status:'failed', error:'unavailable' });\n" +
"    try{ const r=await bot.iptvLookupStatus(String(req.params.id||'')); return res.json(r||{ status:'pending' }); }\n" +
"    catch(e){ return res.json({ status:'pending' }); }\n" +
"  });\n" +
END;

// remove any prior IPTV block precisely (START..END), so neighbouring routes survive
const si = s.indexOf(START);
if (si >= 0) { const ei = s.indexOf(END, si); if (ei >= 0) { let cut = ei + END.length; s = s.slice(0, si) + s.slice(cut); } }

const i = s.indexOf(ANCHOR);
if (i < 0) throw new Error('ANCHOR MISS: FORGOT/RESET comment not found in account.js');
s = s.slice(0, i) + ROUTES + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: /account/tools/iptv/options + /lookup (with body parsers)');
console.log('IPTVHUB PATCH OK');
