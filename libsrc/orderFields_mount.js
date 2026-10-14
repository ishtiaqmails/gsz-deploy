'use strict';
/* Mount routes/orderFields.js in server.js (idempotent). Anchors on the netflixHub mount marker. */
const fs = require('fs');
const GSZ = '/opt/gsz';
const f = GSZ + '/server.js';
let s = fs.readFileSync(f, 'utf8');
if (s.indexOf('orderFields') !== -1) { console.log('orderFields already mounted'); process.exit(0); }
const anchor = '/*NETFLIX_HUB*/';
if (s.indexOf(anchor) === -1) throw new Error('NETFLIX_HUB anchor not found in server.js');
const add = anchor + "\n  try { const orderFieldsRouter = require('./routes/orderFields')(pool); app.use('/', orderFieldsRouter); } catch (e) { console.error('orderFields mount failed:', e.message); } /*ORDER_FIELDS*/";
s = s.replace(anchor, add);
fs.writeFileSync(f, s);
console.log('orderFields mounted');
