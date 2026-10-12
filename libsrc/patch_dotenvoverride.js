'use strict';
/* Make .env authoritative: dotenv.config({override:true}) so values in .env win
   over any stale/empty vars pm2 injected into the process env (this is why the
   Brevo key read as empty at runtime -> email verification never sent).
   server.js. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_dotenvoverride.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'server.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('override: true') >= 0 && /dotenv'\)\.config\([^)]*override: true/.test(s)) { console.log('skip (already): dotenv override'); process.exit(0); }

const FIND = "require('dotenv').config({ path: require('path').join(__dirname, '.env') });";
const REPL = "require('dotenv').config({ path: require('path').join(__dirname, '.env'), override: true });";
const i = s.indexOf(FIND);
if (i < 0) throw new Error('ANCHOR MISS: dotenv.config line');
if (s.indexOf(FIND, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE');
s = s.slice(0, i) + REPL + s.slice(i + FIND.length);
fs.writeFileSync(file, s);
console.log('DOTENV OVERRIDE PATCH OK');
