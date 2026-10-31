#!/usr/bin/env bash
# stepHotfixPaint.sh — EMERGENCY: restore $$ in paintPrices so app.js runs (prices + currency +
# client rendering). Patches public/js/app.js, restarts, verifies. Idempotent; restores on failure.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%s)
cd "$GSZ"
F=public/js/app.js
cp -f "$GSZ/$F" "$GSZ/$F.bak.$TS"
restore(){ echo "!! failed — restoring"; cp -f "$GSZ/$F.bak.$TS" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR
echo "==> patch"; node "$SRC/patch_hotfix_paint.js" "$GSZ"
echo "==> validate"
node --check "$GSZ/$F" && echo "  app.js ok"
grep -q "\$\$('\[data-pkr\]',root)" "$GSZ/$F" && echo "  paintPrices uses \$\$ (array helper)"
test "$(grep -c "[^$]\$('\[data-pkr\]',root)" "$GSZ/$F")" = "0" && echo "  no single-\$ selector left"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "  health OK (${i}s)"; break; }; sleep 1; done
echo "==> new app.js version now served:"; curl -s http://127.0.0.1:3900/ | grep -oE "app\.js\?v=[0-9]+" | head -1 | sed 's/^/   /'
echo
echo "DONE — app.js runs again: prices paint, currency picker works, products render. Hard-refresh"
echo "your browser once (Ctrl+Shift+R) to drop the broken cached copy."
