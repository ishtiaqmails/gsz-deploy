#!/usr/bin/env bash
# recon1 : READ-ONLY. Prints how the GSZ admin handles image uploads so the
# compression engine can hook in correctly. Changes nothing.
cd /opt/gsz

echo "=== 1) sharp installed in /opt/gsz? ==="
node -e "console.log('sharp', require('sharp/package.json').version)" 2>/dev/null || echo "NO sharp in node_modules"

echo; echo "=== 2) multer / upload middleware ==="
grep -rn "multer\|diskStorage\|memoryStorage\|express-fileupload\|formidable\|busboy" routes server.js lib 2>/dev/null | head -30

echo; echo "=== 3) upload handlers (file fields) ==="
grep -rn "\.single(\|\.array(\|\.fields(\|req\.file\|req\.files\|\.mv(" routes server.js 2>/dev/null | head -40

echo; echo "=== 4) where image bytes are written / destination dirs ==="
grep -rn "writeFile\|createWriteStream\|destination\|public/uploads\|uploads/\|/img/\|banner\|logo" routes server.js lib 2>/dev/null | grep -iv "download\|\.css\|\.js'" | head -40

echo; echo "=== 5) upload dirs + total size ==="
for d in public/uploads uploads public/img public/images public/banners public/logos public/media; do
  [ -d "$d" ] && du -sh "$d" 2>/dev/null
done

echo; echo "=== 6) 15 biggest images anywhere under public ==="
find public -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -15 | awk -F'\t' '{printf "%7.0f KB  %s\n",$1/1024,$2}'

echo; echo "=== 7) node version ==="
node -v
echo "=== recon1 done ==="
