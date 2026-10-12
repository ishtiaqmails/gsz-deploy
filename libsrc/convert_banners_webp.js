'use strict';
/* Hero fast-load — convert every hero banner PNG/JPG in public/img into a resized WebP
   (desktop -> 1760px, mobile -> 820px, quality 80). The ~2MB PNGs become ~100-150KB WebP,
   keeping the originals as a <picture> fallback. Prints a size report and WEBP_ALL_OK only
   when every banner has a WebP (the deploy step requires that before switching the markup,
   so the page never points at a WebP that doesn't exist). */
const path = require('path'), fs = require('fs');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node convert_banners_webp.js <ROOT>'); process.exit(1); }
const IMG = path.join(ROOT, 'public/img');

let sharp = null;
try { sharp = require(path.join(ROOT, 'node_modules/sharp')); } catch (e) {}

(async () => {
  if (!sharp) { console.error('WEBP: sharp not available (install: cd ' + ROOT + ' && npm i sharp)'); process.exit(2); }
  let files = [];
  try { files = fs.readdirSync(IMG).filter(f => /^banner-.*\.(png|jpe?g)$/i.test(f)); } catch (e) { console.error('WEBP: cannot read ' + IMG + ': ' + e.message); process.exit(2); }
  if (!files.length) { console.log('WEBP: no banner files found'); console.log('WEBP_ALL_OK'); return; }

  let before = 0, after = 0, ok = 0;
  for (const f of files) {
    const src = path.join(IMG, f);
    const out = path.join(IMG, f.replace(/\.(png|jpe?g)$/i, '.webp'));
    const W = /-mobile-/i.test(f) ? 820 : 1760;
    try {
      const b = fs.statSync(src).size; before += b;
      await sharp(src).resize({ width: W, withoutEnlargement: true }).webp({ quality: 80, effort: 4 }).toFile(out);
      const a = fs.statSync(out).size; after += a; ok++;
      console.log('  ' + f + '  ' + Math.round(b / 1024) + 'KB -> ' + Math.round(a / 1024) + 'KB');
    } catch (e) { console.error('  FAIL ' + f + ': ' + e.message); }
  }
  console.log('WEBP: ' + ok + '/' + files.length + ' converted — ' + (before / 1048576).toFixed(2) + 'MB -> ' + (after / 1048576).toFixed(2) + 'MB');
  if (ok === files.length) console.log('WEBP_ALL_OK');
  else process.exit(3);
})();
