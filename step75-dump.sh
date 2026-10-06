#!/usr/bin/env bash
# step75-dump — READ-ONLY. Prints the files I need to build the customer
# account system (Phase 1) safely: server/session setup, mail sender,
# storefront header, and installed packages. Changes nothing, no restart.
set -euo pipefail
APP=/opt/gsz
show(){ echo; echo "========== $1 =========="; if [ -f "$1" ]; then cat "$1"; else echo "(not found)"; fi; echo "========== END $1 =========="; }

show "$APP/server.js"
show "$APP/package.json"
show "$APP/views/partials/store_top.ejs"

echo; echo "========== MAIL MODULE(S) =========="
# find whatever sends email (nodemailer / sendMail / transport)
grep -rlE "nodemailer|createTransport|sendMail|transporter" "$APP/lib" "$APP/routes" 2>/dev/null | sort -u | while read -r f; do
  echo; echo "---- $f ----"; cat "$f"
done
echo "========== END MAIL =========="

echo; echo "========== lib/ listing =========="; ls -1 "$APP/lib" 2>/dev/null || true
echo "========== routes/ listing =========="; ls -1 "$APP/routes" 2>/dev/null || true
echo "========== views/ listing =========="; ls -1 "$APP/views" 2>/dev/null || true
echo; echo "==> step75-dump done (read-only, nothing changed)"
