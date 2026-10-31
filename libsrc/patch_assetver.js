'use strict';
/* ASSETVER_v1 — auto cache-busting for store assets. ?v= now derives from each file's mtime, so
   any change to app.js / app.css busts browser + Cloudflare cache automatically (fixes the stale
   app.js that froze the currency UI and the mobile category bar). Future-proof: no manual bumps.
   3 edits across server.js, store_top.ejs, store_bottom.ejs. Idempotent; split/join. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';

const HELPER =
  "\nconst _assetFs = require('fs'); const _assetVerCache = {};\n" +
  "app.locals.assetVer = function (p) { if (_assetVerCache[p]) return _assetVerCache[p]; try { _assetVerCache[p] = String(Math.floor(_assetFs.statSync(path.join(__dirname, 'public', p)).mtimeMs)); } catch (e) { _assetVerCache[p] = '1'; } return _assetVerCache[p]; };";

const edits = [
  { file: 'server.js',
    old: "app.use('/static', express.static(path.join(__dirname, 'public'), { maxAge: '7d' }));",
    neu: "app.use('/static', express.static(path.join(__dirname, 'public'), { maxAge: '7d' }));" + HELPER,
    done: "app.locals.assetVer =" },
  { file: 'views/partials/store_top.ejs',
    old: "/static/css/app.css?v=41",
    neu: "/static/css/app.css?v=<%= assetVer('css/app.css') %>",
    done: "app.css?v=<%= assetVer('css/app.css') %>" },
  { file: 'views/partials/store_bottom.ejs',
    old: "/static/js/app.js?v=41",
    neu: "/static/js/app.js?v=<%= assetVer('js/app.js') %>",
    done: "app.js?v=<%= assetVer('js/app.js') %>" },
];

const cache = {};
function load(f) { if (!(f in cache)) cache[f] = fs.readFileSync(path.join(ROOT, f), 'utf8'); return cache[f]; }
let applied = 0, skipped = 0;
for (const e of edits) {
  let s = load(e.file);
  if (s.indexOf(e.done) >= 0) { skipped++; continue; }
  const n = s.split(e.old).length - 1;
  if (n === 0) throw new Error('ANCHOR MISSING in ' + e.file + ': ' + e.old.slice(0, 55));
  if (n !== 1) throw new Error('anchor not unique (' + n + ') in ' + e.file + ': ' + e.old.slice(0, 40));
  cache[e.file] = s.split(e.old).join(e.neu); applied++;
}
for (const f in cache) fs.writeFileSync(path.join(ROOT, f), cache[f]);
console.log('ASSETVER_v1 applied=' + applied + ' skipped=' + skipped);
