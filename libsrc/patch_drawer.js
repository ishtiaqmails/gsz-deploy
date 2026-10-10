'use strict';
/* Repurpose the hamburger drawer: categories already live on the bottom "Store" tab, so replace the
   duplicated category links inside #drawerCats with real site PAGES (Track, Resellers, About, FAQ,
   WhatsApp Channel). Keeps the drawer container + its footer (My account / Change currency / WhatsApp)
   untouched, and reuses the drawer's own .dcat/.cg classes so it looks native. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_drawer.js <ROOT>'); process.exit(1); }
const VIEWS = path.join(ROOT, 'views');

function walk(dir, acc) {
  for (const name of fs.readdirSync(dir)) {
    const fp = path.join(dir, name);
    let st; try { st = fs.statSync(fp); } catch (e) { continue; }
    if (st.isDirectory()) walk(fp, acc);
    else if (/\.ejs$/i.test(name) && !/\.bak/i.test(name)) acc.push(fp);
  }
  return acc;
}

const LINKS =
'\n      <a class="dcat" href="/track" style="--g1:#2a6cff;--g2:#19c6ee"><span class="cg"><svg class="ic" viewBox="0 0 24 24"><path d="M3 7h13l5 5v5h-2"/><path d="M3 7v10h2"/><circle cx="7.5" cy="17.5" r="2"/><circle cx="17.5" cy="17.5" r="2"/></svg></span><span><b>Track an Order</b></span></a>' +
'\n      <a class="dcat" href="/resellers" style="--g1:#7a2bff;--g2:#c23bff"><span class="cg"><svg class="ic" viewBox="0 0 24 24"><path d="M3 21V9l9-6 9 6v12"/><path d="M9 21v-6h6v6"/></svg></span><span><b>Reseller Panels</b></span></a>' +
'\n      <a class="dcat" href="/about" style="--g1:#2a6cff;--g2:#5b8bff"><span class="cg"><svg class="ic" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg></span><span><b>About Us</b></span></a>' +
'\n      <a class="dcat" href="/faq" style="--g1:#19c6ee;--g2:#2a6cff"><span class="cg"><svg class="ic" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M9.6 9a2.4 2.4 0 1 1 3.4 2.2c-.8.4-1 .9-1 1.8M12 17h.01"/></svg></span><span><b>FAQ &amp; Policies</b></span></a>' +
'\n      <a class="dcat" href="https://whatsapp.com/channel/0029VbDvVgCDOQIbbuzNiF11" target="_blank" rel="noopener" style="--g1:#1fb457;--g2:#19c6ee"><span class="cg"><svg class="ic" viewBox="0 0 24 24"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg></span><span><b>WhatsApp Channel</b></span></a>\n    ';

const files = walk(VIEWS, []);
const hits = files.filter(f => { try { return /id=["']drawerCats["']/.test(fs.readFileSync(f, 'utf8')); } catch (e) { return false; } });
if (!hits.length) throw new Error('ANCHOR MISS: no view contains id="drawerCats"');

let patched = 0, skipped = 0;
for (const hit of hits) {
  let s = fs.readFileSync(hit, 'utf8');
  if (s.indexOf('gsz-pages') >= 0) { console.log('skip (already): ' + path.relative(ROOT, hit)); skipped++; continue; }
  const openM = /<div[^>]*id=["']drawerCats["'][^>]*>/.exec(s);
  if (!openM) { console.log('skip (no drawerCats open tag): ' + path.relative(ROOT, hit)); continue; }
  const openEnd = openM.index + openM[0].length;
  // end of the category list: the drawer-foot if present, else the closing </div> of drawerCats
  const footRel = /<div[^>]*class=["'][^"']*drawer-foot[^"']*["'][^>]*>/.exec(s.slice(openEnd));
  const endRel = footRel ? footRel.index : s.slice(openEnd).indexOf('</div>');
  if (endRel < 0) { console.log('skip (no end anchor): ' + path.relative(ROOT, hit)); continue; }
  const endStart = openEnd + endRel;
  const tail = footRel ? '\n  ' : '\n      '; // keep a close tag if we stopped at </div>
  s = s.slice(0, openEnd) + '\n      <!-- gsz-pages -->' + LINKS + tail + s.slice(endStart);
  fs.writeFileSync(hit, s);
  console.log('patched: repurposed drawer categories -> pages in ' + path.relative(ROOT, hit));
  patched++;
}
if (!patched && skipped) console.log('(all drawer copies already repurposed)');
console.log('DRAWER PATCH OK');
