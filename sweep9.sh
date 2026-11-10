#!/usr/bin/env bash
# gsz-sweep9 : revert the site to DARK-ONLY (Midnight).
# Removes the three theme injections: pre-paint script + light-theme.css link
# (store_top.ejs) and themes.js / toggle engine (store_bottom.ejs).
# light-theme.css + themes.js stay on disk (unreferenced) so this is reversible.
set -e
cd /opt/gsz
T=views/partials/store_top.ejs
B=views/partials/store_bottom.ejs

if ! grep -q 'light-theme\.css' "$T" && ! grep -q 'themes\.js' "$B"; then
  echo "already dark-only (theme refs absent)"; exit 0
fi

cp "$T" /opt/gsz/.gsz-darkonly-top-bak
cp "$B" /opt/gsz/.gsz-darkonly-bot-bak

# top partial: drop pre-paint theme script + light css link
sed -i '/gsz_theme/d' "$T"
sed -i '/light-theme\.css/d' "$T"
# bottom partial: drop themes.js (which builds the sun/moon toggle)
sed -i '/themes\.js/d' "$B"

# validate both partials still compile; revert everything on any failure
for f in "$T" "$B"; do
  if ! node -e "require('ejs').compile(require('fs').readFileSync('$f','utf8'),{filename:'$f'})" 2>/tmp/ejserr; then
    echo "EJS compile FAILED on $f — reverting all, no restart:"; cat /tmp/ejserr
    cp /opt/gsz/.gsz-darkonly-top-bak "$T"; cp /opt/gsz/.gsz-darkonly-bot-bak "$B"
    exit 1
  fi
done

# confirm refs are gone
if grep -q 'light-theme\.css' "$T" || grep -q 'gsz_theme' "$T" || grep -q 'themes\.js' "$B"; then
  echo "removal incomplete — reverting"; cp /opt/gsz/.gsz-darkonly-top-bak "$T"; cp /opt/gsz/.gsz-darkonly-bot-bak "$B"; exit 1
fi

pm2 restart gsz
echo "DONE: site is DARK-ONLY (toggle + light theme removed; files kept on disk, unreferenced)"
