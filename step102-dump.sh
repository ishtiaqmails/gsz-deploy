#!/usr/bin/env bash
# step102-dump — READ-ONLY. Prints the cart script + how it's loaded, so I can
# wire guest-cart persistence + merge-into-account on login. Changes nothing.
set -euo pipefail
APP=/opt/gsz
cd "$APP"
echo "========== public/js/cart.js (FULL) =========="
cat public/js/cart.js
echo
echo "========== store_bottom.ejs: cart.js load + version =========="
grep -nE "cart\.js|cart\.css|GSZCart" views/partials/store_bottom.ejs
echo
echo "==> step102-dump done (read-only)"
