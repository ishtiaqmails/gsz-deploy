#!/usr/bin/env bash
# gsz-light-sweep1 : light-theme fixes for form controls (/review), plan pills
# (/resellers), footer social chips, and hamburger menu tiles.
set -e
cd /opt/gsz

if ! grep -q 'gsz-light-sweep1' public/css/light-theme.css; then
cat >> public/css/light-theme.css <<'CSS'

/* === gsz-light-sweep1 : forms + pills + social + menu tiles === */
html[data-theme="light"] select,
html[data-theme="light"] input[type="text"],
html[data-theme="light"] input[type="email"],
html[data-theme="light"] input[type="search"],
html[data-theme="light"] input[type="tel"],
html[data-theme="light"] input[type="number"],
html[data-theme="light"] input[type="url"],
html[data-theme="light"] input[type="password"],
html[data-theme="light"] input:not([type]),
html[data-theme="light"] textarea{
  background:var(--surface) !important;
  color:var(--ink) !important;
  border:1.5px solid var(--line-2) !important;
}
html[data-theme="light"] select option{ background:#ffffff; color:var(--ink); }
html[data-theme="light"] input::placeholder,
html[data-theme="light"] textarea::placeholder{ color:var(--muted) !important; opacity:1; }
html[data-theme="light"] select:focus,
html[data-theme="light"] input:focus,
html[data-theme="light"] textarea:focus{ border-color:var(--v) !important; outline:none; }

html[data-theme="light"] .ppill:not(.sel){
  background:var(--surface) !important;
  border:1.5px solid var(--line) !important;
  color:var(--ink-soft) !important;
}
html[data-theme="light"] .ppill:not(.sel):hover{ background:var(--surface-2) !important; }

html[data-theme="light"] .social a{
  background:var(--surface) !important;
  border:1px solid var(--line) !important;
  color:var(--ink) !important;
}
html[data-theme="light"] .social a:hover{ background:var(--surface-2) !important; }
html[data-theme="light"] .social a svg{ stroke:var(--ink) !important; fill:var(--ink) !important; }

html[data-theme="light"] .gna-tile{
  background:var(--surface) !important;
  border:1px solid var(--line) !important;
}
html[data-theme="light"] .gna-tile:hover{ background:var(--surface-2) !important; }
html[data-theme="light"] .gna-tile b{ color:var(--ink) !important; }
html[data-theme="light"] .gna-tile span,
html[data-theme="light"] .gna-tile small{ color:var(--muted) !important; }
CSS
echo "appended sweep1"
else
echo "sweep1 already present"
fi

NV=$(date +%s)
for F in $(grep -rlE 'light-theme\.css\?v=|themes\.js\?v=' views --include=*.ejs); do
  sed -i -E "s#(light-theme\.css\?v=)[0-9]+#\1$NV#g; s#(themes\.js\?v=)[0-9]+#\1$NV#g" "$F"
done
pm2 restart gsz
echo "DONE v=$NV"
