#!/usr/bin/env bash
# READ ONLY — branding admin (settings edit), reviews table, admin nav, for marquee+reviews.
APP=/opt/gsz
dump(){ echo; echo "========== BEGIN $1 =========="; cat "$1" 2>/dev/null || echo "(missing)"; echo "========== END $1 =========="; }
dump "$APP/views/admin/branding.ejs"
echo; echo "========== which admin route saves settings/branding =========="
grep -rlnE "settings|branding" "$APP/routes" 2>/dev/null | grep -v node_modules
echo "--- routes/admin.js (first 160 lines) ---"; sed -n '1,160p' "$APP/routes/admin.js" 2>/dev/null
echo; echo "========== reviews schema =========="
( sudo -u postgres psql -d gsz -c "\d reviews" 2>&1 || true ) | head -30
echo; echo "========== admin nav (_shell_top.ejs) =========="
cat "$APP/views/admin/_shell_top.ejs" 2>/dev/null
echo "== DONE =="
