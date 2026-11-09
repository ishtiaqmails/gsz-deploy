#!/usr/bin/env bash
# gsz-light-sweep2 : per-credit price pill (.rp-per), footer social outline
# icons (fix the black-blob fill), and a visible header category hover.
set -e
cd /opt/gsz

if ! grep -q 'gsz-light-sweep2' public/css/light-theme.css; then
cat >> public/css/light-theme.css <<'CSS'

/* === gsz-light-sweep2 : price pill + social outline icons + nav hover === */
/* per-credit price pill (resellers) */
html[data-theme="light"] .rp-per{
  background:var(--surface-2) !important;
  border:1px solid var(--line) !important;
  color:var(--ink-soft) !important;
}
html[data-theme="light"] .rp-per .pprice,
html[data-theme="light"] .rp-per .js-per{ color:var(--ink) !important; }

/* footer social chips: clean OUTLINE icons, not filled black blobs */
html[data-theme="light"] .social a{
  background:var(--surface) !important;
  border:1px solid var(--line) !important;
}
html[data-theme="light"] .social a svg{
  fill:none !important;
  stroke:var(--ink) !important;
}
html[data-theme="light"] .social a:hover{ background:var(--surface-2) !important; }
html[data-theme="light"] .social a:hover svg{ stroke:var(--v) !important; }

/* header category links: clearly visible hover */
html[data-theme="light"] .hd a[href^="/category/"]:hover{
  background:var(--surface-2) !important;
  color:var(--v) !important;
  border-radius:8px;
}
CSS
echo "appended sweep2"
else
echo "sweep2 already present"
fi

NV=$(date +%s)
for F in $(grep -rlE 'light-theme\.css\?v=|themes\.js\?v=' views --include=*.ejs); do
  sed -i -E "s#(light-theme\.css\?v=)[0-9]+#\1$NV#g; s#(themes\.js\?v=)[0-9]+#\1$NV#g" "$F"
done
pm2 restart gsz
echo "DONE v=$NV"
