'use strict';
/* gsz-api (BOT BOX) — add a READ-ONLY IPTV line lookup used before any renewal.
   POST /api/iptv-lookup { sku | panel_id, raw, username?, password? }
     -> parseCredsFromText(raw) (self-aware), then the existing _findLine() per panel type,
        returns the line's CURRENT EXPIRY. No renewal, NO credits (device_info is free).
   Reuses renewalService.js internals (_panelType, _findLine, iptvSvc.parseCredsFromText).
   Panel resolved from the site product's sku (SKU-xxxx) or an explicit panel_id.
   Idempotent; aborts (throws) if an anchor moved so the step script can auto-restore. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz-api';

function patch(rel, guard, find, repl){
  const file = path.join(ROOT, rel);
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0){ console.log('skip (already): ' + rel); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + rel);
  if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel);
  s = s.slice(0, i) + repl + s.slice(i + find.length);
  fs.writeFileSync(file, s);
  console.log('patched: ' + rel);
}

/* 1) renewalService.js — add lookupLine() and export it */
const LOOKUP_FN =
"// IPTV_LOOKUP_v1 — read-only: pasted text/username -> detect creds -> find the line on its panel -> current expiry.\n" +
"// No renewal, no credits. Panel resolved from the site product's sku (SKU-xxxx) or an explicit panel_id.\n" +
"async function lookupLine(body){\n" +
"  const { sku, panel_id, raw, username, password } = body||{};\n" +
"  let pid = panel_id || null;\n" +
"  if(!pid && sku){\n" +
"    try { const r=await db.query(\"SELECT iptv_panel_id, delivery_type FROM products WHERE sku=$1 LIMIT 1\",[String(sku)]);\n" +
"      if(r.rows.length){ if(r.rows[0].delivery_type!=='iptv' || !r.rows[0].iptv_panel_id) return { http:200, ok:false, reason:'not_iptv' }; pid=r.rows[0].iptv_panel_id; } } catch(e){}\n" +
"  }\n" +
"  if(!pid) return { http:200, ok:false, reason:'panel_unresolved' };\n" +
"  const ptype=await _panelType(pid);\n" +
"  let u=(username||'').trim()||null, p=(password||'')||null;\n" +
"  if(raw){ let parsed={}; try{ parsed=iptvSvc.parseCredsFromText(raw)||{}; }catch(e){} u=u||(parsed.username||null); p=p||(parsed.password||null); }\n" +
"  if(u) u=String(u).replace(/<[^>]*>/g,'').trim();\n" +
"  if(!u) return { http:200, ok:true, found:false, reason:'no_username' };\n" +
"  const line=await _findLine(pid, ptype, u, p);\n" +
"  if(!line.ok){\n" +
"    if(ptype==='activation_api' && !p) return { http:200, ok:true, found:false, needs_password:true, username:u };\n" +
"    return { http:200, ok:true, found:false, reason: line.transient?'panel_unreachable':'not_found', username:u };\n" +
"  }\n" +
"  return { http:200, ok:true, found:true, username:line.username, panel_id:pid, panel_type:ptype, expiry:line.expiry||null, has_password: !!(line.password||p) };\n" +
"}\n\n";

patch('renewalService.js',
  'async function lookupLine(',
  "module.exports = { startRenew, getStatus };",
  LOOKUP_FN + "module.exports = { startRenew, getStatus, lookupLine };");

/* 2) server.js — add the route right after the renew-status route */
const ROUTE =
"\n// IPTV_LOOKUP_v1 — read-only pre-pay line lookup (expiry) by pasted text/username. No credits.\n" +
"app.post('/api/iptv-lookup', async (req, res) => {\n" +
"  try { const r = await renewalSvc.lookupLine(req.body||{}); const http=r.http||200; delete r.http; return res.status(http).json(r); }\n" +
"  catch(e){ return res.status(500).json({ ok:false, reason:'error', error:e.message }); }\n" +
"});\n";

const RENEW_STATUS_BLOCK =
  "app.get('/api/renew-status/:request_id', async (req, res) => {\n" +
  "  try {\n" +
  "    const r = await renewalSvc.getStatus(req.params.request_id);\n" +
  "    return res.json(r);\n" +
  "  } catch(e) { return res.status(500).json({ status:'pending', error:e.message }); }\n" +
  "});";
patch('server.js', "app.post('/api/iptv-lookup'", RENEW_STATUS_BLOCK, RENEW_STATUS_BLOCK + ROUTE);

console.log('IPTV LOOKUP PATCH OK');
