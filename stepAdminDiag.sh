#!/usr/bin/env bash
# stepAdminDiag.sh — READ ONLY. Admin shell/nav + dcard pattern + route mounting, to build the Library section to match.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ" || { echo "no $GSZ"; exit 1; }

echo "===== 1) admin route files + how they mount ====="
ls -1 routes/admin*.js 2>/dev/null
grep -nE "adminReports|adminInventory|require\('./routes/admin|app.use\('/admin" server.js 2>/dev/null | head -30

echo; echo "===== 2) admin layout / shell + nav items ====="
ls -1 views/admin/ 2>/dev/null | head -40
echo "---- nav partial ----"
grep -rln "admin.*nav\|sidebar\|bottom-nav\|navItems\|a href=\"/admin" views/admin/*.ejs views/partials/*.ejs 2>/dev/null | head
NAVF=$(grep -rln "href=\"/admin/inventory\|href=\"/admin/orders\|Inventory</" views/admin/*.ejs views/partials/*.ejs 2>/dev/null | head -1)
echo "nav file: ${NAVF:-?}"
[ -n "${NAVF:-}" ] && grep -nE "href=\"/admin|<a |label|icon" "$NAVF" | head -40

echo; echo "===== 3) dcard (3 stat cards) pattern — find + show one ====="
DC=$(grep -rln "dcard" views/admin/*.ejs 2>/dev/null | head -1)
echo "dcard example: ${DC:-?}"
[ -n "${DC:-}" ] && { L=$(grep -n "dcard" "$DC" | head -1 | cut -d: -f1); sed -n "$((L>3?L-3:1)),$((L+22))p" "$DC"; }

echo; echo "===== 4) an example section route (render shape) ====="
sed -n '1,40p' routes/adminReports.js 2>/dev/null || sed -n '1,40p' routes/adminInventory.js 2>/dev/null

echo; echo "===== 5) existing /internal/iptv/status handler (reuse) ====="
L=$(grep -n "/internal/iptv/status" routes/iptv.js | head -1 | cut -d: -f1); [ -n "${L:-}" ] && sed -n "${L},$((L+40))p" routes/iptv.js

echo; echo "===== 6) admin view header include pattern (how a view renders shell) ====="
head -15 views/admin/inventory.ejs 2>/dev/null || head -15 views/admin/reports.ejs 2>/dev/null
echo DONE
