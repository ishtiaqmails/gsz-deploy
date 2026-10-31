'use strict';
/* WAITLIST_v1 — mount the admin waitlist route + point the dashboard "View ->" at it.
   adminWaitlist.js + waitlist.ejs are copied in by the step. Idempotent; split/join. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';

const edits = [
  { file: 'server.js',
    old: "app.use('/', ownerPriceRouter);",
    neu: "app.use('/', ownerPriceRouter);\nconst adminWaitlistRouter = require('./routes/adminWaitlist')(pool);\napp.use('/admin', adminWaitlistRouter);",
    done: "adminWaitlistRouter" },
  { file: 'views/admin/dashboard.ejs',
    old: "waiting on restock</div></div><a href=\"/admin/inventory\"",
    neu: "waiting on restock</div></div><a href=\"/admin/waitlist\"",
    done: "waiting on restock</div></div><a href=\"/admin/waitlist\"" },
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
console.log('WAITLIST_v1 applied=' + applied + ' skipped=' + skipped);
