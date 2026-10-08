#!/usr/bin/env bash
# dumpOrders — orders list + detail code (for premium rebuild).
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## routes/adminOrders.js (full) ##########"
cat routes/adminOrders.js
echo
echo "########## views/admin/orders.ejs (full) ##########"
cat views/admin/orders.ejs
echo
echo "########## views/admin/order_detail.ejs (full) ##########"
cat views/admin/order_detail.ejs
echo "== dumpOrders done =="
