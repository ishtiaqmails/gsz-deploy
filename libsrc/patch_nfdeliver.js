'use strict';
/* deliver.js — full-account Netflix delivery text now uses the NEW /assign fields:
   portal login (portal_url + customer username/password) -> Netflix account email/password
   -> instructions. Two call sites. Single-line anchors, guarded + idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_nfdeliver.js <ROOT>'); process.exit(1); }
const F = path.join(ROOT, 'lib/deliver.js');

function sub(name, guard, find, replace) {
  let s = fs.readFileSync(F, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(F, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}

// site 1 (uses r.*)
sub('deliver:assign-text', '(r.customerUsername',
  "'Netflix account (full)\\nLogin page: ' + (r.portalUrl || '') + '\\nUsername: ' + (r.username || email) + '\\nPassword: ' + (r.password || '') + '\\nAccount email: ' + email;",
  "['How to use & get codes:', 'Open: ' + (r.portalUrl || ''), 'Login username: ' + (r.customerUsername || ''), 'Login password: ' + (r.customerPassword || ''), '', 'Your Netflix account:', 'Email: ' + email, 'Password: ' + (r.password || '')].concat(r.instructions ? ['', r.instructions] : []).join('\\n');");

// site 2 (uses _r.*)
sub('deliver:auto-assign-text', '(_r.customerUsername',
  "'Netflix account (full)\\nLogin page: ' + (_r.portalUrl || '') + '\\nUsername: ' + (_r.username || '') + '\\nPassword: ' + (_r.password || '') + '\\nAccount email: ' + (_r.assignedEmail || '');",
  "['How to use & get codes:', 'Open: ' + (_r.portalUrl || ''), 'Login username: ' + (_r.customerUsername || ''), 'Login password: ' + (_r.customerPassword || ''), '', 'Your Netflix account:', 'Email: ' + (_r.assignedEmail || ''), 'Password: ' + (_r.password || '')].concat(_r.instructions ? ['', _r.instructions] : []).join('\\n');");

console.log('NF DELIVER PATCH OK');
