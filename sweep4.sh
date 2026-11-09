#!/usr/bin/env bash
# gsz-light-sweep4 : IPTV library pages (/library/*) — make the selected filter
# chip and the faint card tag chips readable in light theme. Shared template,
# so this covers every IPTV library at once.
set -e
cd /opt/gsz

if ! grep -q 'gsz-light-sweep4' public/css/light-theme.css; then
cat >> public/css/light-theme.css <<'CSS'

/* === gsz-light-sweep4 : IPTV library filter chip + card tags === */
/* selected filter chip (Country/Category "All", active country, etc.) */
html[data-theme="light"] .lib-chip.on{
  background:var(--v) !important;
  border-color:var(--v) !important;
  color:#ffffff !important;
}
html[data-theme="light"] .lib-chip.on i{ color:#ffffff !important; opacity:.85; }

/* channel/title card tag chips (country, quality, episodes) */
html[data-theme="light"] .lib-co,
html[data-theme="light"] .lib-q,
html[data-theme="light"] .lib-ep{
  background:var(--surface-2) !important;
  color:var(--ink-soft) !important;
  border:1px solid var(--line) !important;
}
CSS
echo "appended sweep4"
else
echo "sweep4 already present"
fi

NV=$(date +%s)
for F in $(grep -rlE 'light-theme\.css\?v=|themes\.js\?v=' views --include=*.ejs); do
  sed -i -E "s#(light-theme\.css\?v=)[0-9]+#\1$NV#g; s#(themes\.js\?v=)[0-9]+#\1$NV#g" "$F"
done
pm2 restart gsz
echo "DONE v=$NV"
