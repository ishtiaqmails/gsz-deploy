#!/usr/bin/env bash
# dumpPartials — shared shell partials (logo/fonts/colors) + static mounts, for the dark dashboard shell.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
for f in views/partials/store_top.ejs views/partials/store_bottom.ejs views/partials/auth_style.ejs; do
  echo "################# $f #################"
  [ -f "$f" ] && cat -n "$f" || echo "(missing)"
  echo
done
echo "################# static mounts + views dir (server.js) #################"
grep -nE "express\.static|app\.set\(['\"]view|app\.use\(['\"]/|logo|/img|/static|/assets|/public" server.js 2>/dev/null | head -30
echo "################# logo file setting #################"
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -tAc "SELECT key, value FROM wa_settings WHERE key ~* 'logo|site_name|brand'" 2>&1 | head
echo "== dumpPartials done =="
