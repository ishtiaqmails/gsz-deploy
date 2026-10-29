'use strict';
/* INDEXNOW_AUTO_v1 — start auto-IndexNow from server.js, right after the sitemap router
   is mounted (the sitemap is the URL source). EOL-aware, idempotent, anchor-guarded. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const file = path.join(ROOT, 'server.js');
let s = fs.readFileSync(file, 'utf8');
const EOL = s.indexOf('\r\n') >= 0 ? '\r\n' : '\n';

if (s.indexOf('INDEXNOW_AUTO_v1') >= 0) { console.log('INDEXNOW_AUTO_v1 already present — skip'); process.exit(0); }

const anchor = "app.use('/', sitemapRouter);";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('sitemapRouter mount anchor not found in server.js');
const nl = s.indexOf('\n', i);
if (nl < 0) throw new Error('anchor line end not found');
const at = nl + 1;
const line = "try { require('./lib/indexnow_auto').start(pool, { base: 'https://galaxyzayron.store', port: 3900 }); } catch (e) { console.error('indexnow_auto init', e && e.message); } /* INDEXNOW_AUTO_v1 — submit indexable URLs to IndexNow on boot + daily */" + EOL;
s = s.slice(0, at) + line + s.slice(at);
fs.writeFileSync(file, s);
console.log('INDEXNOW_AUTO_v1 applied');
