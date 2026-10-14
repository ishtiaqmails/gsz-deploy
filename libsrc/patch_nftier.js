'use strict';
/* Make the Netflix per-plan tier an explicit, editable admin setting.
   - product_plans.nf_tier is read alongside the plan.
   - each plan's tier = explicit nf_tier (phone|tv|full) if set, else derived from the label.
   - a POST /netflix/plan/:id/tier handler persists it (mirrors the portal-product handler).
   Idempotent (guards), anchored, unique-checked. Column is added by stepNfTier.sh. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_nftier.js <ROOT>'); process.exit(1); }

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

patch('routes/adminNetflix.js', [
  {
    name: 'select-nf_tier',
    guard: 'nf_portal_product_id, nf_tier FROM product_plans',
    find: 'SELECT id, label, nf_portal_product_id FROM product_plans WHERE product_id=$1 ORDER BY sort, id',
    replace: 'SELECT id, label, nf_portal_product_id, nf_tier FROM product_plans WHERE product_id=$1 ORDER BY sort, id'
  },
  {
    name: 'tier-prefer-explicit',
    guard: "pl.nf_tier) >= 0 ? pl.nf_tier",
    find: 'const tier = gate.tierForPlan(pl.label);',
    replace: "const tier = (['phone','tv','full'].indexOf(pl.nf_tier) >= 0 ? pl.nf_tier : gate.tierForPlan(pl.label));"
  },
  {
    name: 'tier-save-route',
    guard: "/netflix/plan/:id/tier",
    find: "    res.redirect('/admin/netflix?ok=' + encodeURIComponent('Portal product set'));\n  });",
    replace: "    res.redirect('/admin/netflix?ok=' + encodeURIComponent('Portal product set'));\n  });\n\n  router.post('/netflix/plan/:id/tier', auth, body, async (req, res) => {\n    const id = parseInt(req.params.id, 10);\n    const t = String(req.body.tier || '').trim().toLowerCase();\n    const val = ['phone', 'tv', 'full'].indexOf(t) >= 0 ? t : null;\n    try { await pool.query(\"UPDATE product_plans SET nf_tier=$1 WHERE id=$2\", [val, id]); } catch (e) {}\n    res.redirect('/admin/netflix?ok=' + encodeURIComponent('Tier updated'));\n  });"
  }
]);
console.log('NFTIER PATCH OK');
