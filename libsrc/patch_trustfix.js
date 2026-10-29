'use strict';
/* TRUSTFIX_v1 — homepage/product trust + review credibility.
   1) home stats band: render the real value as text (never the literal "0" when the
      count-up doesn't run) — rating + orders delivered.
   2) home review block: remove the Trustpilot logo/word -> first-party note.
   3) home review cards: "Verified buyer" fallback -> "Verified Purchase" (when verified)
      / "Customer Review" otherwise. (adds `verified` to the homeData reviews query)
   4) product trust row: drop "on Trustpilot" and "Verified genuine" -> factual wording.
   Exact single-occurrence anchors; idempotent (skips an edit already applied); throws if an
   anchor is missing so nothing half-applies. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';

const edits = [
  // 1) homeData reviews query: add `verified`
  { file: 'server.js',
    old: 'SELECT author, location, stars, body FROM reviews WHERE approved',
    neu: 'SELECT author, location, stars, body, verified FROM reviews WHERE approved',
    done: 'stars, body, verified FROM reviews WHERE approved' },

  // 2) stat band — rating: show the real value, not 0
  { file: 'views/home.ejs',
    old: 'data-count="<%= ratingRaw %>">0</span>',
    neu: 'data-count="<%= ratingRaw %>"><%= ratingRaw %></span>',
    done: 'data-count="<%= ratingRaw %>"><%= ratingRaw %></span>' },

  // 3) stat band — orders delivered: show the real value (comma-formatted, "+"), not 0
  { file: 'views/home.ejs',
    old: 'data-count="<%= deliveredNum %>">0</span>',
    neu: 'data-count="<%= deliveredNum %>"><%= deliveredNum.toLocaleString(\'en-US\') %>+</span>',
    done: 'deliveredNum.toLocaleString(\'en-US\') %>+</span>' },

  // 4) review block — remove Trustpilot logo -> first-party verified-purchase note
  { file: 'views/home.ejs',
    old: '<div class="tp-logo"><svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg>Trustpilot</div>',
    neu: '<div class="tp-logo" style="font-size:12px;font-weight:600;line-height:1.45;display:block;opacity:.85">&#10003; &ldquo;Verified Purchase&rdquo; reviews are from customers with completed Galaxy Zayron orders.</div>',
    done: 'Verified Purchase&rdquo; reviews are from customers with completed Galaxy Zayron orders.' },

  // 5) review cards — proper verified label
  { file: 'views/home.ejs',
    old: "<span><%= r.location || 'Verified buyer' %></span>",
    neu: "<span><% if (r.verified) { %>&#10003; Verified Purchase<% } else { %><%= r.location || 'Customer Review' %><% } %></span>",
    done: 'r.verified) { %>&#10003; Verified Purchase<% } else' },

  // 6) product trust row — drop "on Trustpilot"
  { file: 'views/product.ejs',
    old: ' on Trustpilot</span>',
    neu: ' by our customers</span>',
    done: ' by our customers</span>' },

  // 7) product trust row — replace "Verified genuine"
  { file: 'views/product.ejs',
    old: 'Verified genuine</span>',
    neu: 'Verified-purchase reviews</span>',
    done: 'Verified-purchase reviews</span>' },
];

const cache = {};
function load(f) { if (!(f in cache)) cache[f] = fs.readFileSync(path.join(ROOT, f), 'utf8'); return cache[f]; }

let applied = 0, skipped = 0;
for (const e of edits) {
  let s = load(e.file);
  if (s.indexOf(e.old) >= 0) {
    if (s.split(e.old).length - 1 !== 1) throw new Error('anchor not unique in ' + e.file + ': ' + e.old.slice(0, 40));
    cache[e.file] = s.replace(e.old, e.neu); applied++;
  } else if (s.indexOf(e.done) >= 0) { skipped++; }
  else throw new Error('ANCHOR MISSING in ' + e.file + ': ' + e.old.slice(0, 50));
}

for (const f in cache) fs.writeFileSync(path.join(ROOT, f), cache[f]);
console.log('TRUSTFIX_v1 applied=' + applied + ' skipped=' + skipped);
