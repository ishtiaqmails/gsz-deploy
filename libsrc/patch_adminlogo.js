'use strict';
/* Use the real site logo (/static/img/logo.png) in the admin sidebar brand, with the
   gradient-star mark kept as an automatic fallback if the image ever fails to load.
   Edits views/admin/_shell_top.ejs: one CSS rule + wrap the existing mark in a hidden
   fallback and add the <img>. Idempotent; aborts if an anchor is missing/not unique. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_adminlogo.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'views/admin/_shell_top.ejs');
let s = fs.readFileSync(file, 'utf8');

const edits = [
  { name: 'sblogo-css',
    guard: '.sblogo{height:34px',
    find: '.brand .dim{display:block;font-size:11px;color:var(--muted);font-weight:600;letter-spacing:.01em}',
    repl: '.brand .dim{display:block;font-size:11px;color:var(--muted);font-weight:600;letter-spacing:.01em}\n  .sblogo{height:34px;width:auto;max-width:200px;object-fit:contain;display:block}' },
  { name: 'brand-img',
    guard: 'class="sblogo"',
    find: '<div class="brand"><span class="logo"><svg width="20" height="20" viewBox="0 0 24 24" fill="#fff"><path d="M12 2l2.4 6.2L21 9l-5 4 1.6 7L12 16.6 6.4 20 8 13 3 9l6.6-.8L12 2z"/></svg></span>',
    repl: '<div class="brand"><img src="/static/img/logo.png" alt="Galaxy Subz × Zayron" class="sblogo" onerror="this.style.display=\'none\';document.getElementById(\'sbFb\').style.display=\'inline-flex\'"><span id="sbFb" style="display:none;align-items:center;gap:11px"><span class="logo"><svg width="20" height="20" viewBox="0 0 24 24" fill="#fff"><path d="M12 2l2.4 6.2L21 9l-5 4 1.6 7L12 16.6 6.4 20 8 13 3 9l6.6-.8L12 2z"/></svg></span>' },
  { name: 'brand-fb-close',
    guard: '</span></b></span></div>',
    find: '<b>Galaxy Subz<span class="dim">× Zayron · Admin</span></b></div>',
    repl: '<b>Galaxy Subz<span class="dim">× Zayron · Admin</span></b></span></div>' }
];

for (const e of edits) {
  if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + e.name); continue; }
  const first = s.indexOf(e.find);
  if (first < 0) throw new Error('ANCHOR MISS: ' + e.name);
  if (s.indexOf(e.find, first + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + e.name);
  s = s.slice(0, first) + e.repl + s.slice(first + e.find.length);
  console.log('patched: ' + e.name);
}
fs.writeFileSync(file, s);
console.log('ADMIN LOGO PATCH OK');
