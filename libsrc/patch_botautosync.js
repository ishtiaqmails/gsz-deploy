'use strict';
/* BOTSYNC_AUTO_v1 — start automatic bot-catalogue sync from server.js.
   Inserts one line right after the cartsync router is mounted (pool in scope).
   EOL-aware, idempotent, throws if the anchor is missing so it never half-applies. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const file = path.join(ROOT, 'server.js');
let s = fs.readFileSync(file, 'utf8');
const EOL = s.indexOf('\r\n') >= 0 ? '\r\n' : '\n';

if (s.indexOf('BOTSYNC_AUTO_v1') >= 0) { console.log('BOTSYNC_AUTO_v1 already present — skip'); process.exit(0); }

const anchor = "const cartSyncRouter = require('./routes/cartsync')(pool);";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('cartsync anchor not found in server.js');
const nl = s.indexOf('\n', i);
if (nl < 0) throw new Error('cartsync line end not found');
const at = nl + 1;
const line = "try { require('./lib/botsync_auto')(pool, 600000); } catch (e) { console.error('botsync_auto init', e && e.message); } /* BOTSYNC_AUTO_v1 — auto-pull bot catalogue every 10 min + on boot */" + EOL;
s = s.slice(0, at) + line + s.slice(at);
fs.writeFileSync(file, s);
console.log('BOTSYNC_AUTO_v1 applied');
