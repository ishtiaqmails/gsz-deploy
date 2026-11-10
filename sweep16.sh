#!/usr/bin/env bash
# gsz-sweep16 : transparent image optimizer. For GET /static/*.{jpg,png}, when
# the browser accepts WebP, serve a resized, quality-kept WebP (cached) instead
# of the heavy original. Covers product images, category banners, reseller panel
# images, payment/maintenance logos AND all existing images — with NO change to
# any file name or DB reference. Safe no-op pass-through if sharp isn't available.
set -e
cd /opt/gsz

# idempotency
if [ -f lib/imgopt.js ] && grep -q "imgopt" server.js; then echo "sweep16 already applied"; exit 0; fi

echo "=== install sharp (image engine) ==="
npm install sharp --no-audit --no-fund 2>&1 | tail -5 || echo "npm had issues"
node -e "require('sharp'); console.log('sharp OK', require('sharp/package.json').version)" 2>/dev/null \
  || echo "WARN: sharp not loadable yet — optimizer will pass through originals (site unaffected)"

cp server.js /opt/gsz/.gsz-s16-server.bak

# 1) the optimizer middleware
cat > lib/imgopt.js <<'IMGOPT'
// Transparent image optimizer. For GET /static/*.{jpg,png}, when the browser
// sends Accept: image/webp, serve a resized WebP (cached on disk) instead of the
// big original. Originals, file names and DB references are never changed. If
// sharp is unavailable this is a pure pass-through and the original is served.
const fs = require('fs');
const path = require('path');
let sharp = null; try { sharp = require('sharp'); } catch (e) {}

module.exports = function (opts) {
  opts = opts || {};
  const PUB = path.join(__dirname, '..', 'public');
  const CACHE = path.join(__dirname, '..', '.imgcache');
  try { fs.mkdirSync(CACHE, { recursive: true }); } catch (e) {}
  const MAXW = opts.maxWidth || 1600;

  return function (req, res, next) {
    try {
      if (!sharp || req.method !== 'GET') return next();
      const ext = (/\.(jpe?g|png)$/i.exec(req.path) || [])[1];
      if (!ext) return next();
      if (String(req.headers['accept'] || '').indexOf('image/webp') === -1) return next();
      const rel = decodeURIComponent(req.path).replace(/^\/+/, '');
      if (rel.indexOf('..') !== -1) return next();
      const src = path.join(PUB, rel);
      if (src.indexOf(PUB + path.sep) !== 0) return next();
      let st; try { st = fs.statSync(src); } catch (e) { return next(); }
      if (!st.isFile()) return next();
      const key = rel.replace(/[^a-z0-9]/gi, '_') + '-' + Math.round(st.mtimeMs) + '-' + st.size + '.webp';
      const cf = path.join(CACHE, key);
      const send = function () {
        res.set('Content-Type', 'image/webp');
        res.set('Vary', 'Accept');
        res.set('Cache-Control', 'public, max-age=31536000, immutable');
        const rs = fs.createReadStream(cf);
        rs.on('error', function () { try { next(); } catch (e) {} });
        rs.pipe(res);
      };
      if (fs.existsSync(cf)) return send();
      const q = /png$/i.test(ext) ? 90 : 80; // PNGs are often logos/graphics — keep them crisp
      sharp(src, { failOn: 'none' }).rotate()
        .resize({ width: MAXW, withoutEnlargement: true })
        .webp({ quality: q })
        .toBuffer()
        .then(function (buf) {
          if (!buf || buf.length === 0 || buf.length >= st.size) return next(); // never serve bigger
          try { fs.writeFileSync(cf, buf); } catch (e) {}
          send();
        })
        .catch(function () { next(); });
    } catch (e) { try { next(); } catch (_) {} }
  };
};
IMGOPT

# 2) mount it just BEFORE the existing /static express.static handler
cat > /tmp/s16edit.js <<'JS'
const fs=require('fs');
const f='server.js';
let s=fs.readFileSync(f,'utf8');
function one(a,b){const n=s.split(a).length-1;if(n!==1){console.error('EXPECT 1, got '+n+' for: '+a);process.exit(3);}s=s.replace(a,b);}
one(`app.use('/static', express.static(`,
    `app.use('/static', require('./lib/imgopt')());\napp.use('/static', express.static(`);
fs.writeFileSync(f,s);
console.log('optimizer mounted before static');
JS
node /tmp/s16edit.js || { echo "mount edit failed — reverting"; cp /opt/gsz/.gsz-s16-server.bak server.js; rm -f lib/imgopt.js; exit 1; }

# 3) validate
if ! node --check lib/imgopt.js 2>/tmp/e1; then echo "imgopt.js syntax error — reverting:"; cat /tmp/e1; cp /opt/gsz/.gsz-s16-server.bak server.js; rm -f lib/imgopt.js; exit 1; fi
if ! node --check server.js 2>/tmp/e2; then echo "server.js syntax error — reverting:"; cat /tmp/e2; cp /opt/gsz/.gsz-s16-server.bak server.js; rm -f lib/imgopt.js; exit 1; fi

pm2 restart gsz
sleep 2

# 4) pre-warm the heavy banners + panels so the first visitor is instant
echo "=== pre-warming heavy images (banners + panels) ==="
for img in public/img/banner-*.png public/img/panel-*.png; do
  [ -f "$img" ] || continue
  name=$(basename "$img")
  curl -s -H 'Accept: image/webp' "http://127.0.0.1:3900/static/img/$name" -o /dev/null && echo "warmed $name"
done

echo; echo "=== cache size (optimized WebP versions) ==="
du -sh .imgcache 2>/dev/null

echo; echo "=== before/after on one banner ==="
B=$(ls -1 public/img/banner-*.png 2>/dev/null | head -1)
if [ -n "$B" ]; then
  echo "original: $(du -h "$B" | cut -f1)  $B"
  curl -s -H 'Accept: image/webp' "http://127.0.0.1:3900/static/img/$(basename "$B")" -o /tmp/_w.webp && echo "served webp: $(du -h /tmp/_w.webp | cut -f1)"
  rm -f /tmp/_w.webp
fi
echo "DONE: image optimizer live — /static images serve resized WebP, originals untouched"
