#!/usr/bin/env bash
# dumpAdminShell — the admin shell (sidebar nav + layout) so the mobile app-model (bottom nav bar,
# app top bar) can be built to match the website's app feel.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "########## views/admin/_shell_top.ejs ##########"
cat views/admin/_shell_top.ejs
echo
echo "########## views/admin/_shell_bottom.ejs ##########"
cat views/admin/_shell_bottom.ejs
echo "== dumpAdminShell done =="
