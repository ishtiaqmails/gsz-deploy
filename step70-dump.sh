#!/usr/bin/env bash
APP=/opt/gsz
echo "========== BEGIN views/admin/orders.ejs =========="; cat "$APP/views/admin/orders.ejs" 2>/dev/null || echo "(missing)"; echo "========== END =========="
echo "== DONE =="
