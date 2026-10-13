'use strict';
/* patch_contentseo.js — guides/articles always get a meta description (in-place, idempotent).
   The article head already renders metaDescription/canonical/OG/Article-JSON-LD; it was only ever
   empty when a post had no excerpt. Add a body-derived fallback so every article has a description,
   and make each content hub's list description unique (not the same line on every hub). */
const fs = require('fs');
const GSZ = '/opt/gsz';
const f = GSZ + '/routes/content.js';
let s = fs.readFileSync(f, 'utf8');

if (s.indexOf('CONTENT_SEO_v1') !== -1) { console.log('CONTENT_SEO already present — skip'); process.exit(0); }

// 1) article: body-derived meta description fallback when excerpt/seo.description are empty
const a1 = "metaDescription: seo.description || post.excerpt || '',";
if (s.indexOf(a1) === -1) throw new Error('article metaDescription anchor not found');
const r1 = "metaDescription: seo.description || post.excerpt || (String(bodyHtml||'').replace(/<[^>]+>/g,' ').replace(/&[a-z#0-9]+;/gi,' ').replace(/\\s+/g,' ').trim().slice(0,160).replace(/\\s+\\S*$/,'')) || ((post.title||'') + ' \\u2014 ' + s.siteName), /*CONTENT_SEO_v1*/";
s = s.replace(a1, r1);

// 2) content list: unique per-hub description instead of the same sentence on every hub
const a2 = "metaDescription: 'Guides, reviews, comparisons and news from ' + s.siteName + '.',";
if (s.indexOf(a2) !== -1) {
  const r2 = "metaDescription: PREFIX_TITLE[prefix] + ' for IPTV and digital subscriptions \\u2014 expert ' + String(PREFIX_TITLE[prefix]||'').toLowerCase() + ', tips and reviews from ' + s.siteName + '.',";
  s = s.replace(a2, r2);
}

fs.writeFileSync(f, s);
console.log('CONTENT_SEO PATCH applied');
