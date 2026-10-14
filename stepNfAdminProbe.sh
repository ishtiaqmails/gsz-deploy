#!/usr/bin/env bash
# stepNfAdminProbe.sh — READ-ONLY. Find the live Netflix admin route and show how it builds
# per-plan tier + its POST handlers, so I can add an editable tier dropdown with zero guesswork.
set -u
GSZ=/opt/gsz; cd "$GSZ"

F=$(grep -rlE "res\.render\('admin/netflix'|/admin/netflix/plan/|netflix/stock/add" --include=*.js . 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head -1)
echo "ROUTE FILE: ${F:-NOT FOUND}"
[ -z "${F:-}" ] && { echo "searching wider..."; grep -rlE "portalFree|nf_enabled" --include=*.js . 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head; exit 0; }
echo "lines: $(wc -l < "$F")"

echo ""
echo "--- module shape (exports / router) ---"
grep -nE "module.exports|express.Router|function *\(pool|require\('.*netflixGate" "$F" | head

echo ""
echo "--- how each plan's TIER is set (derived? column?) ---"
grep -nE "tier|tierForPlan|nf_tier|PLAN_ALLOW" "$F" | head -15

echo ""
echo "--- plan SELECT(s) feeding the page ---"
grep -nE "FROM product_plans|SELECT .*label|\.full|portal_product_id|nf_portal_product_id" "$F" | head -15

echo ""
echo "--- existing POST handlers (mirror one for tier save) ---"
grep -nE "router\.(post|get)\(" "$F" | head -20

echo ""
echo "--- the /plan/:id/portal handler body (template for /plan/:id/tier) ---"
awk '/\/plan\/.*portal/{f=NR} f&&NR>=f&&NR<=f+12{print NR": "$0}' "$F" | head -14
