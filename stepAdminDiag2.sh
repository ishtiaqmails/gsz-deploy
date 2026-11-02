#!/usr/bin/env bash
# stepAdminDiag2.sh — READ ONLY. Phone ingest handler + dashboard section links + shell nav, to wire the Library section.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ" || { echo "no $GSZ"; exit 1; }

echo "===== 1) phone ingest handler (routes/iptv.js ~75-120) ====="
L=$(grep -n "ingest/:server" routes/iptv.js | head -1 | cut -d: -f1)
echo "ingest at line ${L:-?}"
[ -n "${L:-}" ] && sed -n "${L},$((L+40))p" routes/iptv.js

echo; echo "===== 2) worker store() definition + call site (confirm exact text) ====="
grep -n "async function store\|await store(\|items, enh.adult\|if (!r.ok) return { server, fail" lib/iptv/worker.js

echo; echo "===== 3) dashboard section links (how sections are reached) ====="
grep -nE "href=\"/admin/(inventory|netflix|trials|mapping|reports|customers)" views/admin/dashboard.ejs 2>/dev/null | head -20
echo "---- dashboard tile/link block ----"
DL=$(grep -n "href=\"/admin/inventory" views/admin/dashboard.ejs 2>/dev/null | head -1 | cut -d: -f1)
[ -n "${DL:-}" ] && sed -n "$((DL>4?DL-4:1)),$((DL+10))p" views/admin/dashboard.ejs

echo; echo "===== 4) _shell_top: any desktop side-nav links? ====="
grep -nE "href=\"/admin/(orders|reports|inventory|products)|sidenav|side-nav|<aside|snav" views/admin/_shell_top.ejs 2>/dev/null | head -20

echo; echo "===== 5) IPTV_INGEST key name + agent INTERVAL (for resync trigger) ====="
grep -nE "IPTV_INGEST_KEY|INTERVAL|servers\?stale|forceTrial|fresh=1" routes/iptv.js lib/iptv/worker.js 2>/dev/null | head -12
echo DONE
