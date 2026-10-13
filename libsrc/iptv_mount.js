'use strict';
/* Mount the IPTV route in server.js — idempotent, single-layer (no nested escaping). */
const fs = require('fs');
const f = process.argv[2] || '/opt/gsz/server.js';
let s = fs.readFileSync(f, 'utf8');
if (s.indexOf('iptvRouter') >= 0) { console.log('iptv route already mounted'); process.exit(0); }
const add = "\nconst iptvRouter = require('./routes/iptv')(pool);\napp.use('/', iptvRouter);";
const anchors = ["app.use('/', trialsRouter);", 'app.use("/", trialsRouter);'];
let done = false;
for (const a of anchors) {
  const i = s.indexOf(a);
  if (i >= 0) { s = s.slice(0, i + a.length) + add + s.slice(i + a.length); done = true; break; }
}
if (!done) { console.error('MOUNT ANCHOR NOT FOUND (app.use trialsRouter)'); process.exit(2); }
fs.writeFileSync(f, s);
console.log('iptv route mounted after trialsRouter');
