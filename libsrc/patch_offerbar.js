'use strict';
/* Premium top offer/marquee bar — swap the flat dark gradient for a brand
   blue->indigo->purple gradient (crisp white text), subtle depth highlights.
   public/css/app.css. Idempotent; aborts if the anchor moved. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_offerbar.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'public/css/app.css');
let s = fs.readFileSync(file, 'utf8');

const GUARD = '/*offerPremium*/';
if (s.indexOf(GUARD) >= 0) { console.log('skip (already): premium offer bar'); process.exit(0); }

const FIND = '.offer{background:linear-gradient(90deg,#0a0c18,#120a24 50%,#0a0c18);border-bottom:1px solid var(--line);color:#fff;font-size:13.5px;overflow:hidden}';
const REPL = '.offer{/*offerPremium*/background:linear-gradient(100deg,#2f7bff 0%,#5b4bf0 48%,#8b45ff 100%);border-bottom:1px solid rgba(255,255,255,.16);color:#fff;font-size:13.5px;overflow:hidden;box-shadow:inset 0 1px 0 rgba(255,255,255,.16),inset 0 -1px 0 rgba(0,0,0,.14)}';

const i = s.indexOf(FIND);
if (i < 0) throw new Error('ANCHOR MISS: .offer rule');
if (s.indexOf(FIND, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: .offer');
s = s.slice(0, i) + REPL + s.slice(i + FIND.length);
fs.writeFileSync(file, s);
console.log('PREMIUM OFFER BAR PATCH OK');
