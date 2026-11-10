#!/usr/bin/env bash
# recon2 : READ-ONLY. Pins the LIVE upload routes (no .bak), their save dirs,
# field names, and the panel-image upload. Changes nothing.
cd /opt/gsz

LIVE=$(grep -rln "multer" routes --include="*.js" | grep -vE '\.bak|\.xbak')
echo "=== LIVE route files using multer ==="
echo "$LIVE"

for f in $LIVE; do
  echo; echo "========== $f =========="
  grep -nE "const UP|const IMG|IMG_DIR|UP[[:space:]]*=|destination:|\.single\(|\.array\(|\.fields\(|router\.(post|put)\(" "$f" | head -24
done

echo; echo "=== where UP / IMG_DIR point (definitions) ==="
grep -rnE "UP[[:space:]]*=|IMG_DIR[[:space:]]*=|IMG[[:space:]]*=" routes --include="*.js" | grep -vE '\.bak|\.xbak' | head -20

echo; echo "=== panel image upload route (live) ==="
grep -rnE "panel" routes --include="*.js" | grep -vE '\.bak|\.xbak' | grep -iE "upload|single|post|image|\.png|img" | head -20

echo; echo "=== is adminProductImage mounted? how is it required in server.js ==="
grep -nE "adminProductImage|adminPayments|branding|require\('./routes/admin" server.js | head -20
echo "=== recon2 done ==="
