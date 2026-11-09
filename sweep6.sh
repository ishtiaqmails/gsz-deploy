#!/usr/bin/env bash
# gsz-light-sweep6 : product page blue "Note" banner (.note-box) — pale-on-pale
# in light theme; give it a light-blue tint, blue label/icon, dark body text.
set -e
cd /opt/gsz

if ! grep -q 'gsz-light-sweep6' public/css/light-theme.css; then
cat >> public/css/light-theme.css <<'CSS'

/* === gsz-light-sweep6 : product "Note" info banner === */
html[data-theme="light"] .note-box{
  background:#eef4ff !important;
  border:1px solid rgba(37,99,235,.22) !important;
  color:var(--ink-soft) !important;
}
html[data-theme="light"] .note-box b,
html[data-theme="light"] .note-box strong,
html[data-theme="light"] .note-box .lbl{ color:var(--b) !important; }
html[data-theme="light"] .note-box svg{ stroke:var(--b) !important; fill:none !important; }
CSS
echo "appended sweep6"
else
echo "sweep6 already present"
fi

NV=$(date +%s)
for F in $(grep -rlE 'light-theme\.css\?v=|themes\.js\?v=' views --include=*.ejs); do
  sed -i -E "s#(light-theme\.css\?v=)[0-9]+#\1$NV#g; s#(themes\.js\?v=)[0-9]+#\1$NV#g" "$F"
done
pm2 restart gsz
echo "DONE v=$NV"
