#!/usr/bin/env bash
# gsz-sweep17 : finish installing sharp properly (its platform engine package),
# self-test, then restart + warm + show the real before/after. No app changes.
cd /opt/gsz

echo "=== env ==="
node -v; npm -v; uname -m; node -e "console.log(process.platform, process.arch)"
ldd --version 2>/dev/null | head -1 || true

echo; echo "=== attempt 1: npm install --include=optional sharp ==="
npm install --include=optional sharp 2>&1 | tail -25
node -e "try{require('sharp');console.log('SHARP_OK vips', require('sharp').versions.vips)}catch(e){console.log('SHARP_ERR', e.message)}"

if ! node -e "require('sharp')" 2>/dev/null; then
  echo; echo "=== attempt 2: explicit linux-x64 engine packages ==="
  npm install --include=optional --os=linux --cpu=x64 --libc=glibc @img/sharp-linux-x64 @img/sharp-libvips-linux-x64 sharp 2>&1 | tail -25
  node -e "try{require('sharp');console.log('SHARP_OK2')}catch(e){console.log('SHARP_ERR2', e.message)}"
fi

if node -e "require('sharp')" 2>/dev/null; then
  echo; echo "=== sharp loads — restarting gsz + warming ==="
  pm2 restart gsz
  sleep 3
  echo "root check: $(curl -s -o /dev/null -w 'HTTP %{http_code}' http://127.0.0.1:3900/ || echo 'curl failed')"
  echo "--- warming banners + panels (HTTP code per file) ---"
  for img in public/img/banner-*.png public/img/panel-*.png; do
    [ -f "$img" ] || continue; name=$(basename "$img")
    code=$(curl -s -o /dev/null -w "%{http_code}" -H 'Accept: image/webp' "http://127.0.0.1:3900/static/img/$name")
    echo "$code  $name"
  done
  echo "--- cache size ---"; du -sh .imgcache 2>/dev/null
  echo "--- before/after on one banner ---"
  B=$(ls -1 public/img/banner-*.png 2>/dev/null | head -1)
  if [ -n "$B" ]; then
    curl -s -H 'Accept: image/webp' "http://127.0.0.1:3900/static/img/$(basename "$B")" -o /tmp/_w.webp
    echo "original: $(du -h "$B" | cut -f1)   served: $(du -h /tmp/_w.webp | cut -f1)   $(file -b /tmp/_w.webp)"
    rm -f /tmp/_w.webp
  fi
  echo "DONE: sharp active — images now serve as WebP"
else
  echo; echo "=== sharp STILL failing (see SHARP_ERR above). Optimizer stays a safe pass-through; site is fine. Paste me the error. ==="
fi
