'use strict';
/* Inject the app bottom-nav site-wide by placing <%- include(app_nav) %> right before the
   shared <footer class="ft">. Discovers which .ejs under views/ holds that footer, and computes
   the correct relative include path from that file to views/partials/app_nav.ejs.
   Admin pages use a different shell (_shell_*), so they are untouched — exactly right. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_appnav.js <ROOT>'); process.exit(1); }
const VIEWS = path.join(ROOT, 'views');
const MARK = '<footer class="ft">';
const TARGET = path.join(VIEWS, 'partials/app_nav.ejs');

function walk(dir, acc) {
  for (const name of fs.readdirSync(dir)) {
    const fp = path.join(dir, name);
    let st; try { st = fs.statSync(fp); } catch (e) { continue; }
    if (st.isDirectory()) walk(fp, acc);
    else if (/\.ejs$/i.test(name) && !/\.bak/i.test(name)) acc.push(fp);
  }
  return acc;
}

const files = walk(VIEWS, []);
const hits = files.filter(f => { try { return fs.readFileSync(f, 'utf8').indexOf(MARK) >= 0; } catch (e) { return false; } });
if (!hits.length) throw new Error('ANCHOR MISS: no view contains <footer class="ft"> — cannot place app nav');

let placed = 0, skipped = 0;
for (const f of hits) {
  let s = fs.readFileSync(f, 'utf8');
  if (s.indexOf("'" + 'app_nav' + "'") >= 0 || s.indexOf('app_nav') >= 0) { skipped++; continue; }
  let rel = path.relative(path.dirname(f), TARGET).replace(/\\/g, '/').replace(/\.ejs$/, '');
  if (!rel.startsWith('.')) rel = './' + rel;
  const inc = "<%- include('" + rel + "') %>\n";
  const idx = s.indexOf(MARK);
  s = s.slice(0, idx) + inc + s.slice(idx);
  fs.writeFileSync(f, s);
  console.log('patched: app nav include added to ' + path.relative(ROOT, f) + "  (include '" + rel + "')");
  placed++;
}
if (!placed && skipped) console.log('skip (already): app nav include present');
console.log('APPNAV PATCH OK');
