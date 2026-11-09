#!/usr/bin/env bash
# gsz-light-sweep7 : product warranty (.warr-note) + availability (.geo-note)
# banners — their coloured labels/icons were too pale in light theme.
set -e
cd /opt/gsz

if ! grep -q 'gsz-light-sweep7' public/css/light-theme.css; then
cat >> public/css/light-theme.css <<'CSS'

/* === gsz-light-sweep7 : warranty + availability banners === */
/* warranty (green) */
html[data-theme="light"] .warr-note{
  background:#edf7f1 !important;
  border:1px solid rgba(16,122,75,.22) !important;
  color:var(--ink-soft) !important;
}
html[data-theme="light"] .warr-note b,
html[data-theme="light"] .warr-note strong,
html[data-theme="light"] .warr-note .lbl{ color:var(--ok) !important; }
html[data-theme="light"] .warr-note svg{ stroke:var(--ok) !important; fill:none !important; }

/* availability note (amber) */
html[data-theme="light"] .geo-note{
  background:#fdf5e9 !important;
  border:1px solid rgba(138,90,0,.22) !important;
  color:var(--ink-soft) !important;
}
html[data-theme="light"] .geo-note b,
html[data-theme="light"] .geo-note strong,
html[data-theme="light"] .geo-note .lbl{ color:var(--warn) !important; }
html[data-theme="light"] .geo-note svg{ stroke:var(--warn) !important; fill:none !important; }
CSS
echo "appended sweep7"
else
echo "sweep7 already present"
fi

NV=$(date +%s)
for F in $(grep -rlE 'light-theme\.css\?v=|themes\.js\?v=' views --include=*.ejs); do
  sed -i -E "s#(light-theme\.css\?v=)[0-9]+#\1$NV#g; s#(themes\.js\?v=)[0-9]+#\1$NV#g" "$F"
done
pm2 restart gsz
echo "DONE v=$NV"
