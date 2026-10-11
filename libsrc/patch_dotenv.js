'use strict';
/* Fix env loading: make server.js load /opt/gsz/.env from the script's own directory
   (__dirname) instead of the process cwd, so the full .env (incl. BREVO_API_KEY) is read
   no matter where pm2 starts the app. dotenv does not override vars already in the
   environment, so only missing ones are added. Idempotent; aborts if the anchor moved. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_dotenv.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'server.js');
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf("__dirname, '.env'") >= 0) { console.log('dotenv: already path-anchored (skip)'); process.exit(0); }
const FIND = "require('dotenv').config();";
const REPL = "require('dotenv').config({ path: require('path').join(__dirname, '.env') });";
const i = s.indexOf(FIND);
if (i < 0) throw new Error('ANCHOR MISS: dotenv config line not found');
if (s.indexOf(FIND, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE');
s = s.slice(0, i) + REPL + s.slice(i + FIND.length);
fs.writeFileSync(file, s);
console.log('dotenv: now loads .env from __dirname');
