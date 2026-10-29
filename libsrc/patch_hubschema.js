'use strict';
/* HUBSCHEMA_v1 — add CollectionPage + BreadcrumbList JSON-LD to the content hub LIST pages
   (/blog, /guides, /buying-guides). Uses vars already in scope (base, prefix, PREFIX_TITLE).
   Anchors on the index,follow list render (not the noindex 404 one). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const file = path.join(ROOT, 'routes/content.js');
let s = fs.readFileSync(file, 'utf8');

const DONE = "jsonLd: (function(){ var B=base||'https://galaxyzayron.store'; var T=(PREFIX_TITLE[prefix]";
if (s.indexOf(DONE) >= 0) { console.log('HUBSCHEMA_v1 already present — skip'); process.exit(0); }

const OLD = "robotsMeta: 'index,follow', ogTags: '', jsonLd: '',";
const NEW = "robotsMeta: 'index,follow', ogTags: '', jsonLd: (function(){ var B=base||'https://galaxyzayron.store'; var T=(PREFIX_TITLE[prefix]||'Articles'); return JSON.stringify([{ '@context':'https://schema.org','@type':'CollectionPage', name:T, url:B+'/'+prefix },{ '@context':'https://schema.org','@type':'BreadcrumbList', itemListElement:[{ '@type':'ListItem', position:1, name:'Home', item:B+'/' },{ '@type':'ListItem', position:2, name:T, item:B+'/'+prefix }] }]).replace(/</g,'\\u003c'); })(),";

if (s.indexOf(OLD) < 0) throw new Error('hub-list render anchor not found');
if (s.split(OLD).length - 1 !== 1) throw new Error('hub-list anchor not unique');
s = s.replace(OLD, NEW);
fs.writeFileSync(file, s);
console.log('HUBSCHEMA_v1 applied');
