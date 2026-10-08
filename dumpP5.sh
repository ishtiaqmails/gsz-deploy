#!/usr/bin/env bash
# dumpP5 — full admin catalog + mapping editors (to safely add per-duration plans)
GSZ=/opt/gsz; cd "$GSZ"
echo "### routes/adminCatalog.js ###"; cat -n routes/adminCatalog.js
echo
echo "### routes/adminMapping.js ###"; cat -n routes/adminMapping.js
echo
echo "### views/admin/product_edit.ejs ###"; cat -n views/admin/product_edit.ejs
echo
echo "### views/admin/mapping.ejs ###"; cat -n views/admin/mapping.ejs
