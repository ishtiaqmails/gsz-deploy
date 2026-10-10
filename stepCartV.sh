#!/usr/bin/env bash
# Cache-bust cart.css (its ?v= lives in a different partial than app.css, so stepMobile missed it).
set -Eeuo pipefail
GSZ=/opt/gsz; TS=$(date +%s)
cd "$GSZ"
F="$(grep -rl 'cart.css?v=' views --include='*.ejs' | grep -v '\.bak' | head -1)"
[ -n "$F" ] || { echo "!! no view references cart.css?v="; exit 1; }
cur="$(grep -oE 'cart\.css\?v=[0-9]+' "$F" | head -1 | grep -oE '[0-9]+$')"
[ -n "$cur" ] || { echo "!! couldn't read cart.css version in $F"; exit 1; }
new=$((cur+1))
cp -f "$F" "$F.bak.$TS"
sed -i "s#cart\.css?v=${cur}#cart.css?v=${new}#g" "$F"
echo "  $F : cart.css v${cur} -> v${new}"
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — cart.css cache-busted; full-width mobile cart now served."
