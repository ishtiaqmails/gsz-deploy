#!/usr/bin/env bash
# dumpStage4.sh — read-only. (A) verify the public product page passes price_usd; (B) recon for
# Stage 4: where to add the buffer control (admin settings save pattern + nav) and the owner
# price endpoint (auth middleware + bot webhook secret to reuse). Targeted.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
win(){ awk -v s="$2" -v e="$3" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$1"; }

echo "### A1) which route renders the public 'product' template ###"
grep -rnE "render\('product'|render\(\"product\"" routes/ 2>/dev/null | grep -v node_modules | head
echo
echo "### A2) plan queries in products.js (does any select price_usd?) ###"
grep -nE "price_pkr|price_usd|FROM product_plans|SELECT" routes/products.js 2>/dev/null | grep -iE "product_plans|price_" | head -20

echo
echo "### B1) admin routes + which save wa_settings / settings ###"
grep -rlnE "wa_settings|INSERT INTO settings|UPDATE settings|ON CONFLICT" routes/admin*.js routes/*dmin*.js 2>/dev/null | grep -v node_modules | head
echo "--- adminWhatsapp save pattern (how a wa_settings key is written from admin) ---"
grep -nE "wa_settings|ON CONFLICT|router\.(get|post)|auth|render\(" routes/adminWhatsapp.js 2>/dev/null | head -25

echo
echo "### B2) admin auth middleware + admin nav (where to add a Pricing/buffer control) ###"
grep -rnE "function auth|const auth|req.session.admin|requireAdmin" routes/*.js server.js 2>/dev/null | grep -v node_modules | head
grep -rnoE "href=\"/admin/[a-z]+\"" views/admin/*.ejs views/partials/*.ejs 2>/dev/null | grep -v node_modules | sort -u | head -20

echo
echo "### C) bot webhook secret (reuse for owner price endpoint auth) + existing /api routes ###"
grep -rnE "wa_bot_webhook_secret|webhook_secret|OWNER_|api_key|x-api-key|bearer" routes/*.js server.js lib/*.js 2>/dev/null | grep -v node_modules | head -12
grep -rnoE "router\.(get|post)\('/api/[a-zA-Z/_:-]+'" routes/*.js 2>/dev/null | grep -v node_modules | head -20
echo "== END =="
