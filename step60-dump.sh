#!/usr/bin/env bash
# READ ONLY — storefront lib + the home route, for the trending toggle wiring.
APP=/opt/gsz
dump(){ echo; echo "========== BEGIN $1 =========="; cat "$1" 2>/dev/null || echo "(missing)"; echo "========== END $1 =========="; }
dump "$APP/lib/storefront.js"
echo; echo "========== where home is rendered =========="
grep -rnE "render\('home'|render\(\"home\"" "$APP/routes" "$APP/server.js" 2>/dev/null
echo "--- the file(s) rendering home (context) ---"
for f in $(grep -rlE "render\('home'|render\(\"home\"" "$APP/routes" "$APP/server.js" 2>/dev/null); do
  echo "===== $f ====="; sed -n '1,80p' "$f"
done
echo "== DONE =="
