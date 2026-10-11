'use strict';
/* Portal product type (4th fulfilment type). A plan can be delivered from the Accounts Portal,
   mapped by nf_portal_product_id (same mapping the Netflix section uses — never disturbs the portal).
   - adminNetflix.js: expose GET /netflix/portal-products.json (reuses the existing read-only helper)
   - adminCatalog.js: model.json returns nf_portal_product_id; model-save accepts source 'portal' and
     persists nf_portal_product_id (null for non-portal plans).
   Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_portal.js <ROOT>'); process.exit(1); }

/* ---- adminNetflix.js: portal-products JSON route ---- */
(function(){
  const file = path.join(ROOT, 'routes/adminNetflix.js');
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf('/netflix/portal-products.json') >= 0) { console.log('netflix: route present (skip)'); return; }
  const ANCH = "  router.post('/netflix/plan/:id/portal', auth, body, async (req, res) => {";
  const NEW = "  router.get('/netflix/portal-products.json', auth, async (req, res) => { try { res.json({ ok: true, products: await portalProducts() }); } catch (e) { res.json({ ok: true, products: [] }); } });\n";
  if (s.indexOf(ANCH) >= 0) { s = s.replace(ANCH, NEW + ANCH); fs.writeFileSync(file, s); console.log('netflix: portal-products.json route added'); }
  else { console.log('netflix: anchor missing (skip)'); }
})();

/* ---- adminCatalog.js: nf_portal_product_id in read + save ---- */
(function(){
  const file = path.join(ROOT, 'routes/adminCatalog.js');
  let s = fs.readFileSync(file, 'utf8'); let ch = false;

  // model.json SELECT
  const SEL = "custom_fields,required_fields,version_labels,avail_from,avail_until,popular FROM product_plans";
  const SEL2 = "custom_fields,required_fields,version_labels,avail_from,avail_until,popular,nf_portal_product_id FROM product_plans";
  if (s.indexOf(SEL2) < 0 && s.indexOf(SEL) >= 0) { s = s.replace(SEL, SEL2); ch = true; console.log('catalog A: model.json +nf_portal_product_id'); }
  else { console.log('catalog A: present/anchor missing (skip)'); }

  // source validation
  const V = "if (['inventory','bot','manual'].indexOf(source) < 0) source = 'manual';";
  const V2 = "if (['inventory','bot','manual','portal'].indexOf(source) < 0) source = 'manual';";
  if (s.indexOf("'portal'].indexOf(source)") < 0 && s.indexOf(V) >= 0) { s = s.replace(V, V2); ch = true; console.log('catalog B: source +portal'); }
  else { console.log('catalog B: present/anchor missing (skip)'); }

  // nfpid variable
  const BT = "const bot_type = source === 'bot' ? ((pl.bot_type || '').trim() || null) : null;";
  const BT2 = BT + "\n        const nfpid = source === 'portal' ? (parseInt(pl.nf_portal_product_id, 10) || null) : null;";
  if (s.indexOf("const nfpid = source === 'portal'") < 0 && s.indexOf(BT) >= 0) { s = s.replace(BT, BT2); ch = true; console.log('catalog C: nfpid var'); }
  else { console.log('catalog C: present/anchor missing (skip)'); }

  // UPDATE query
  const UQ = "popular=$18,sort=$19 WHERE id=$20 AND product_id=$21 RETURNING id',";
  const UQ2 = "popular=$18,sort=$19,nf_portal_product_id=$20 WHERE id=$21 AND product_id=$22 RETURNING id',";
  if (s.indexOf(UQ2) < 0 && s.indexOf(UQ) >= 0) { s = s.replace(UQ, UQ2); ch = true; console.log('catalog D: UPDATE query'); }
  else { console.log('catalog D: present/anchor missing (skip)'); }

  // UPDATE values
  const UV = "pop, i, existingId, id]);";
  const UV2 = "pop, i, nfpid, existingId, id]);";
  if (s.indexOf(UV2) < 0 && s.indexOf(UV) >= 0) { s = s.replace(UV, UV2); ch = true; console.log('catalog E: UPDATE values'); }
  else { console.log('catalog E: present/anchor missing (skip)'); }

  // INSERT query
  const IQ = "popular,sort) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::jsonb,$15::jsonb,$16::jsonb,$17,$18,$19,$20) RETURNING id',";
  const IQ2 = "popular,sort,nf_portal_product_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::jsonb,$15::jsonb,$16::jsonb,$17,$18,$19,$20,$21) RETURNING id',";
  if (s.indexOf(IQ2) < 0 && s.indexOf(IQ) >= 0) { s = s.replace(IQ, IQ2); ch = true; console.log('catalog F: INSERT query'); }
  else { console.log('catalog F: present/anchor missing (skip)'); }

  // INSERT values
  const IV = "au, pop, i]);";
  const IV2 = "au, pop, i, nfpid]);";
  if (s.indexOf(IV2) < 0 && s.indexOf(IV) >= 0) { s = s.replace(IV, IV2); ch = true; console.log('catalog G: INSERT values'); }
  else { console.log('catalog G: present/anchor missing (skip)'); }

  if (ch) fs.writeFileSync(file, s);
})();

console.log('PORTAL-BACKEND OK');
