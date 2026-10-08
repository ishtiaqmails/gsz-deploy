'use strict';
/* CS-3 patches: mount the content router in server.js (after checkout) and add an
   OPTIONAL SEO meta block to store_top.ejs (guarded by typeof — existing pages
   unaffected). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_cs3.js <ROOT>'); process.exit(1); }
function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    const first = s.indexOf(e.find);
    if (first < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
    if (s.indexOf(e.find, first + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
    s = s.slice(0, first) + e.replace + s.slice(first + e.find.length);
    console.log('patched: ' + rel + ' :: ' + e.name);
  }
  fs.writeFileSync(file, s);
}

patch('server.js', [{
  name: 'content-mount',
  guard: "require('./routes/content')",
  find: "const checkoutRouter = require('./routes/checkout')(pool);\napp.use('/', checkoutRouter);",
  replace: "const checkoutRouter = require('./routes/checkout')(pool);\napp.use('/', checkoutRouter);\nconst contentRouter = require('./routes/content')(pool);\napp.use('/', contentRouter);"
}]);

const titleLine = "<title><%= typeof title!=='undefined' ? title : siteName %></title>";
const seoBlock = "\n<%/*cs-seo*/%><% if (typeof metaDescription!=='undefined' && metaDescription) { %><meta name=\"description\" content=\"<%= metaDescription %>\"><% } %><% if (typeof canonicalUrl!=='undefined' && canonicalUrl) { %><link rel=\"canonical\" href=\"<%= canonicalUrl %>\"><% } %><% if (typeof robotsMeta!=='undefined' && robotsMeta) { %><meta name=\"robots\" content=\"<%= robotsMeta %>\"><% } %><% if (typeof ogTags!=='undefined' && ogTags) { %><%- ogTags %><% } %><% if (typeof jsonLd!=='undefined' && jsonLd) { %><script type=\"application/ld+json\"><%- jsonLd %></script><% } %>";
patch('views/partials/store_top.ejs', [{
  name: 'seo-meta', guard: '/*cs-seo*/',
  find: titleLine, replace: titleLine + seoBlock
}]);

console.log('CS3 PATCHES OK');
