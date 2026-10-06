#!/usr/bin/env bash
# READ ONLY — for country-restrictions (#2): products schema + admin product editor location.
APP=/opt/gsz
PSQL(){ sudo -u postgres psql -d gsz -c "$1" 2>&1 || psql -U gsz_user -d gsz -c "$1" 2>&1; }
echo "========== products schema =========="
PSQL "\d products" | head -50
echo; echo "========== admin routes/views that edit a product =========="
grep -rlE "products|product" "$APP/routes" 2>/dev/null | grep -iE "admin|product" | head
echo "--- views/admin listing ---"; ls "$APP/views/admin" 2>/dev/null
echo; echo "========== grep: where product edit form lives =========="
grep -rlnE "short_desc|long_desc|UPDATE products" "$APP/routes" "$APP/views" 2>/dev/null | head
echo "== DONE =="
