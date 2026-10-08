#!/usr/bin/env bash
# dumpInvViews — the two inventory views for premium rebuild.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## views/admin/inventory.ejs (full) ##########"
cat views/admin/inventory.ejs
echo
echo "########## views/admin/inventory_manage.ejs (full) ##########"
cat views/admin/inventory_manage.ejs
echo "== dumpInvViews done =="
