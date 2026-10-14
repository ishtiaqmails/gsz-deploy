'use strict';
/* SEO Batch 2a — blog/guide title + meta description.
   content.js: title uses full post.title when seo.title is a truncated prefix of it (fixes
   existing posts); meta description fills to a proper length from body text when excerpt is short.
   csblocks.js: word-boundary trim on the stored seo.title (no mid-word cuts on future saves).
   Single-line / span anchors, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_seo2.js <ROOT>'); process.exit(1); }
const CT = path.join(ROOT, 'routes/content.js');
const CB = path.join(ROOT, 'lib/csblocks.js');

function once(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find); if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}
function span(file, name, guard, startStr, endStr, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(startStr); if (i < 0) throw new Error('SPAN START MISS: ' + name);
  const j = s.indexOf(endStr, i); if (j < 0) throw new Error('SPAN END MISS: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(j + endStr.length));
  console.log('patched: ' + name);
}

// 1) content.js — full title when seo.title is a truncated prefix
once(CT, 'content:title', 'post.title.indexOf(seo.title) !== 0',
  "title: (seo.title || post.title) + ' · ' + s.siteName,",
  "title: ((seo.title && post.title && post.title.indexOf(seo.title) !== 0) ? seo.title : (post.title || seo.title || s.siteName)) + ' · ' + s.siteName,");

// 2) content.js — stronger meta description (fill from body when excerpt is short)
span(CT, 'content:metadesc', 'CONTENT_SEO_v2',
  "metaDescription: seo.description || post.excerpt || (String(bodyHtml",
  "/*CONTENT_SEO_v1*/",
  "metaDescription: (function(){ var d=(seo.description||post.excerpt||'').trim(); if(d.length>=120) return d.slice(0,160); var _b=String(bodyHtml||'').replace(/<[^>]+>/g,' ').replace(/&[a-z#0-9]+;/gi,' ').replace(/\\s+/g,' ').trim(); var _m=(d?(d+' '+_b):_b).slice(0,160).replace(/\\s+\\S*$/,''); return _m||((post.title||'')+' — '+s.siteName); })(), /*CONTENT_SEO_v2*/");

// 3) csblocks.js — word-boundary title trim
once(CB, 'csblocks:title-trim', 'return t.length<=70?t:t.slice(0,70)',
  "title: String(seoIn.title || pkg.metaTitle || title).slice(0, 70),",
  "title: (function(t){ t=String(t); return t.length<=70?t:t.slice(0,70).replace(/\\s+\\S*$/,''); })(seoIn.title || pkg.metaTitle || title),");

console.log('SEO2 PATCH OK');
