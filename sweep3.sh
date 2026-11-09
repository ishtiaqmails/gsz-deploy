#!/usr/bin/env bash
# gsz-light-sweep3 : product page — make the washed-out stat numbers and the
# "Best for" region tags readable in light theme.
set -e
cd /opt/gsz

if ! grep -q 'gsz-light-sweep3' public/css/light-theme.css; then
cat >> public/css/light-theme.css <<'CSS'

/* === gsz-light-sweep3 : product stat numbers + "Best for" tags === */
/* preview stats strip (iq-bar) */
html[data-theme="light"] .iq-stat b{ color:var(--ink) !important; }
html[data-theme="light"] .iq-go{ color:var(--v) !important; }
html[data-theme="light"] .iq-go svg{ stroke:var(--v) !important; fill:none !important; }

/* "Best for" recommendation tags (iq-reco) */
html[data-theme="light"] .iq-reco-lab{ color:var(--muted) !important; }
html[data-theme="light"] .iq-rg i{ color:var(--ink) !important; }
html[data-theme="light"] .iq-rg em{
  color:var(--ink-soft) !important;
  background:var(--surface-2) !important;
  border:1px solid var(--line) !important;
}

/* "What's inside" popup tiles (same stat pattern) */
html[data-theme="light"] .wi-tile{ background:var(--surface) !important; border:1px solid var(--line) !important; }
html[data-theme="light"] .wi-tile b{ color:var(--ink) !important; }
html[data-theme="light"] .wi-tile span{ color:var(--muted) !important; }
CSS
echo "appended sweep3"
else
echo "sweep3 already present"
fi

NV=$(date +%s)
for F in $(grep -rlE 'light-theme\.css\?v=|themes\.js\?v=' views --include=*.ejs); do
  sed -i -E "s#(light-theme\.css\?v=)[0-9]+#\1$NV#g; s#(themes\.js\?v=)[0-9]+#\1$NV#g" "$F"
done
pm2 restart gsz
echo "DONE v=$NV"
