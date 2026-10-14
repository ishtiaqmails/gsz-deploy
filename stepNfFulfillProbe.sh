#!/usr/bin/env bash
# stepNfFulfillProbe.sh — READ-ONLY. Map lib/deliver.js (delivery flow), plan resolution,
# source branches, and any Portal provisioning client — enough to build Netflix auto-assign.
set -u
GSZ=/opt/gsz; cd "$GSZ"

D=lib/deliver.js
echo "=== lib/deliver.js (lines: $( [ -f "$D" ] && wc -l < "$D" || echo '?' )) ==="
echo "--- exports / main entry ---"
grep -nE "module.exports|exports\.|async function|function deliver|deliverOrder" "$D" 2>/dev/null | head
echo "--- source / type branches (inventory/bot/portal) ---"
grep -nE "source|'inventory'|'portal'|'bot'|'manual'|delivery_type|nf_enabled|netflix" "$D" 2>/dev/null | head -25
echo "--- plan resolution (product_plans) + duration/expiry ---"
grep -nE "product_plans|plan_label|plan_id|duration_value|duration_unit|expires|interval|nf_portal_product_id|plan_tier" "$D" 2>/dev/null | head -20
echo "--- where it sets credentials / marks delivered / stock pick ---"
grep -nE "credentials|delivered|stock|nf_account|UPDATE orders|status=|assign" "$D" 2>/dev/null | head -20

echo ""
echo "=== Portal provisioning client (for Full accounts) ==="
grep -rlE "portalProducts|nf_portal_product_id|internal/.*account|portal.*create|provision|NF_READ_KEY|3100" --include=*.js lib routes 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head
echo "--- portal endpoints referenced ---"
grep -rnE "internal/[a-z-]+|3100|portalProducts|provision|create-account|NF_PORTAL" --include=*.js lib routes 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head -15

echo ""
echo "=== where deliver.js is invoked (post-payment hook) ==="
grep -rnE "require\(.*deliver|deliver\(|deliverOrder\(" --include=*.js routes lib 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head
