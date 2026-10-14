#!/usr/bin/env bash
# stepNfPlanProbe.sh — READ-ONLY. (1) Does the gate already classify the 6 real Netflix
# labels into phone/tv/full correctly? (2) How does routes/adminCatalog.js save plans and
# which template is the product editor? Tells me exactly how to add an explicit per-plan tier.
set -u
GSZ=/opt/gsz; cd "$GSZ"

echo "=== gate tier derivation for the 6 real labels ==="
node -e "
const R='$GSZ'; let g; try{ g=require(R+'/lib/netflixGate'); }catch(e){ console.log('gate load FAIL:',e.message); process.exit(0);}
['1 Profile - 1 Phone/Laptop (Pakistan)','1 Profile - 1 TV (Pakistan)','1 Profile - 1 Phone/Laptop (Global)','1 Profile - 1 TV (Global)','Full Account - Pakistan','Full Account - Global'].forEach(function(l){
  var t=g.tierForPlan?g.tierForPlan(l):'(no fn)';
  var a=(g.PLAN_ALLOW&&g.PLAN_ALLOW[t])?g.PLAN_ALLOW[t].join(','):'?';
  console.log(t.padEnd(6)+' <- '+l+'   [allows: '+a+']');
});
"

echo ""
echo "=== routes/adminCatalog.js ==="
F=routes/adminCatalog.js
if [ ! -f "$F" ]; then echo "NOT FOUND at $F"; F=$(grep -rlE "product_plans" --include=*.js routes 2>/dev/null | grep -v node_modules | head -1); echo "using: ${F:-none}"; fi
[ -z "${F:-}" ] && exit 0
echo "lines: $(wc -l < "$F")"
echo "--- product editor template(s) it renders ---"
grep -nE "res\.render\(" "$F" | grep -iE "product|plan|catalog" | head
echo "--- plan save: how plan_* and source/nf_portal are read + written ---"
grep -nE "plan_label|plan_price|plan_source|plan_tier|nf_portal|product_plans|\.source|sort" "$F" | head -30

echo ""
echo "=== which product-edit template exists in views ==="
ls -1 views/ 2>/dev/null | grep -iE "product" | head
echo "--- source/tier controls already in the big product model template? ---"
for T in views/adm_product_model.ejs views/adm_product_edit.ejs; do
  [ -f "$T" ] && { echo "[$T]"; grep -nE "plan_source|plan_tier|nf_portal|>Inventory<|>Portal<|name=\"source\"|Tier|Phone|TV|Full Account" "$T" | head -12; }
done
