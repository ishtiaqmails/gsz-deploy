'use strict';
/* Mount routes/netflixHub.js in server.js (idempotent). Anchors on the trials router mount. */
const fs = require('fs');
const GSZ = '/opt/gsz';
const f = GSZ + '/server.js';
let s = fs.readFileSync(f, 'utf8');
if (s.indexOf('netflixHub') !== -1) { console.log('netflixHub already mounted'); process.exit(0); }
const anchor = "app.use('/', trialsRouter);";
if (s.indexOf(anchor) === -1) throw new Error('trialsRouter mount anchor not found in server.js');
const add = anchor + "\n  try { const netflixHubRouter = require('./routes/netflixHub')(pool); app.use('/', netflixHubRouter); } catch (e) { console.error('netflixHub mount failed:', e.message); } /*NETFLIX_HUB*/";
s = s.replace(anchor, add);
fs.writeFileSync(f, s);
console.log('netflixHub mounted');
