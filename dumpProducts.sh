#!/usr/bin/env bash
# dumpProducts — products list + edit code + schema (for premium rebuild).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## routes that serve products (grep) ##########"
grep -nE "router\.(get|post)\('/products" routes/adminCatalog.js | head -60
echo
echo "########## routes/adminCatalog.js (full) ##########"
cat routes/adminCatalog.js
echo
echo "########## views/admin/products.ejs (full) ##########"
cat views/admin/products.ejs
echo "== dumpProducts done (product_edit.ejs comes next) =="
