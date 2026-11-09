#!/usr/bin/env bash
# gsz-light-sweep5 : product "What's Inside" tab — make the faint country
# chips (.wi-chip) readable in light theme.
set -e
cd /opt/gsz

if ! grep -q 'gsz-light-sweep5' public/css/light-theme.css; then
cat >> public/css/light-theme.css <<'CSS'

/* === gsz-light-sweep5 : "What's Inside" country chips === */
html[data-theme="light"] .wi-chip{
  background:var(--surface-2) !important;
  color:var(--ink-soft) !important;
  border:1px solid var(--line) !important;
}
html[data-theme="light"] .wi-meta{ color:var(--muted) !important; }
CSS
echo "appended sweep5"
else
echo "sweep5 already present"
fi

NV=$(date +%s)
for F in $(grep -rlE 'light-theme\.css\?v=|themes\.js\?v=' views --include=*.ejs); do
  sed -i -E "s#(light-theme\.css\?v=)[0-9]+#\1$NV#g; s#(themes\.js\?v=)[0-9]+#\1$NV#g" "$F"
done
pm2 restart gsz
echo "DONE v=$NV"
