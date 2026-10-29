'use strict';
/* SEOFIX_v1 — clear the issues the SEO QA found, no design changes.
   - store_top.ejs: alt="" on the Meta Pixel noscript image (clears "img no-alt" sitewide)
   - server.js: trim homepage meta description under 160 chars
   - category.js: add meta description + canonical + robots + CollectionPage/ItemList/Breadcrumb JSON-LD
   - category.ejs: add a screen-reader H1 (cat name) — zero visual change
   - resellers.ejs: add a screen-reader H1
   - pages.js: add meta description + canonical + robots + JSON-LD to /about, /resellers, /faq
   Exact single-occurrence anchors per file; idempotent; throws if an anchor is missing. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
var SR = 'position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;margin:-1px';

const edits = [
  // 1) Meta Pixel noscript image -> alt=""
  { file: 'views/partials/store_top.ejs',
    old: '<noscript><img height="1" width="1" style="display:none"',
    neu: '<noscript><img alt="" height="1" width="1" style="display:none"',
    done: '<noscript><img alt="" height="1"' },

  // 2) homepage meta description under 160 chars (ASCII tail only; keeps the unicode prefix intact)
  { file: 'server.js',
    old: 'buy premium IPTV, streaming and digital subscriptions at the best prices. Instant automated delivery, real WhatsApp support, and free IPTV trials.',
    neu: 'buy premium IPTV, streaming & digital subscriptions at the best prices. Instant delivery, real WhatsApp support, free IPTV trials.',
    done: 'streaming & digital subscriptions at the best prices. Instant delivery' },

  // 3) category route: add SEO locals to the render object
  { file: 'routes/category.js',
    old: 'siteName, logoFile, waNumber, cats, cat, products, total, page, pages, bannerMap, settings, shellJson',
    neu: "metaDescription: ('Shop ' + cat.name + ' at ' + siteName + ' \\u2014 ' + total + ' products, instant delivery and real WhatsApp support.').slice(0,158), canonicalUrl: 'https://galaxyzayron.store/category/' + cat.slug + (page > 1 ? ('?page=' + page) : ''), robotsMeta: 'index,follow', jsonLd: (function(){ var B='https://galaxyzayron.store'; var it=(products||[]).map(function(p,i){ return { '@type':'ListItem', position: ((page-1)*24)+i+1, url: B+'/product/'+(p.slug||''), name: p.name||'' }; }); return JSON.stringify([{ '@context':'https://schema.org','@type':'CollectionPage', name: cat.name, url: B+'/category/'+cat.slug, isPartOf:{ '@type':'WebSite', url: B+'/' }, mainEntity:{ '@type':'ItemList', numberOfItems: total, itemListElement: it } },{ '@context':'https://schema.org','@type':'BreadcrumbList', itemListElement:[{ '@type':'ListItem', position:1, name:'Home', item:B+'/' },{ '@type':'ListItem', position:2, name:cat.name, item:B+'/category/'+cat.slug }] }]).replace(/</g,'\\u003c'); })(), siteName, logoFile, waNumber, cats, cat, products, total, page, pages, bannerMap, settings, shellJson",
    done: "canonicalUrl: 'https://galaxyzayron.store/category/'" },

  // 4) category.ejs: screen-reader H1
  { file: 'views/category.ejs',
    old: "<%- include('partials/store_top') %>",
    neu: "<%- include('partials/store_top') %>\n<h1 style=\"" + SR + "\"><%= cat.name %></h1>",
    done: '<h1 style="' + SR + '"><%= cat.name %></h1>' },

  // 5) resellers.ejs: screen-reader H1
  { file: 'views/resellers.ejs',
    old: "<%- include('partials/store_top') %>",
    neu: "<%- include('partials/store_top') %>\n<h1 style=\"" + SR + "\">IPTV Reseller Panels</h1>",
    done: '>IPTV Reseller Panels</h1>' },

  // 6) pages.js /about
  { file: 'routes/pages.js',
    old: "res.render('about', Object.assign({ title: 'About · ' + s.siteName }, s));",
    neu: "res.render('about', Object.assign({ title: 'About · ' + s.siteName, metaDescription: 'About ' + s.siteName + ' \\u2014 who we are, how we deliver, and why customers trust us for IPTV and digital subscriptions.', canonicalUrl: 'https://galaxyzayron.store/about', robotsMeta: 'index,follow', jsonLd: JSON.stringify([{ '@context':'https://schema.org','@type':'AboutPage', name:'About '+s.siteName, url:'https://galaxyzayron.store/about' },{ '@context':'https://schema.org','@type':'BreadcrumbList', itemListElement:[{ '@type':'ListItem', position:1, name:'Home', item:'https://galaxyzayron.store/' },{ '@type':'ListItem', position:2, name:'About', item:'https://galaxyzayron.store/about' }] }]).replace(/</g,'\\u003c') }, s));",
    done: "canonicalUrl: 'https://galaxyzayron.store/about'" },

  // 7) pages.js /resellers
  { file: 'routes/pages.js',
    old: "res.render('resellers', Object.assign({ title: 'Reseller panels · ' + s.siteName, panels: _panels, bannerMap: _bmap }, s));",
    neu: "res.render('resellers', Object.assign({ title: 'Reseller panels · ' + s.siteName, metaDescription: 'Become an IPTV reseller with ' + s.siteName + ' \\u2014 pick a panel, get credits, and start selling with real WhatsApp support.', canonicalUrl: 'https://galaxyzayron.store/resellers', robotsMeta: 'index,follow', jsonLd: JSON.stringify([{ '@context':'https://schema.org','@type':'WebPage', name:'IPTV Reseller Panels', url:'https://galaxyzayron.store/resellers' },{ '@context':'https://schema.org','@type':'BreadcrumbList', itemListElement:[{ '@type':'ListItem', position:1, name:'Home', item:'https://galaxyzayron.store/' },{ '@type':'ListItem', position:2, name:'Reseller panels', item:'https://galaxyzayron.store/resellers' }] }]).replace(/</g,'\\u003c'), panels: _panels, bannerMap: _bmap }, s));",
    done: "canonicalUrl: 'https://galaxyzayron.store/resellers'" },

  // 8) pages.js /faq
  { file: 'routes/pages.js',
    old: "res.render('faq', Object.assign({ title: 'FAQ & policies · ' + s.siteName }, s));",
    neu: "res.render('faq', Object.assign({ title: 'FAQ & policies · ' + s.siteName, metaDescription: s.siteName + ' FAQ & policies \\u2014 delivery, replacements, warranty, refunds, and how our IPTV and streaming orders work.', canonicalUrl: 'https://galaxyzayron.store/faq', robotsMeta: 'index,follow', jsonLd: JSON.stringify([{ '@context':'https://schema.org','@type':'WebPage', name:'FAQ & policies', url:'https://galaxyzayron.store/faq' },{ '@context':'https://schema.org','@type':'BreadcrumbList', itemListElement:[{ '@type':'ListItem', position:1, name:'Home', item:'https://galaxyzayron.store/' },{ '@type':'ListItem', position:2, name:'FAQ', item:'https://galaxyzayron.store/faq' }] }]).replace(/</g,'\\u003c') }, s));",
    done: "canonicalUrl: 'https://galaxyzayron.store/faq'" },
];

const cache = {};
function load(f) { if (!(f in cache)) cache[f] = fs.readFileSync(path.join(ROOT, f), 'utf8'); return cache[f]; }
let applied = 0, skipped = 0;
for (const e of edits) {
  const s = load(e.file);
  if (s.indexOf(e.done) >= 0) { skipped++; }                 // already applied (done-marker first = idempotent even when old ⊂ new)
  else if (s.indexOf(e.old) >= 0) {
    if (s.split(e.old).length - 1 !== 1) throw new Error('anchor not unique in ' + e.file + ': ' + e.old.slice(0, 40));
    cache[e.file] = s.replace(e.old, e.neu); applied++;
  } else throw new Error('ANCHOR MISSING in ' + e.file + ': ' + e.old.slice(0, 55));
}
for (const f in cache) fs.writeFileSync(path.join(ROOT, f), cache[f]);
console.log('SEOFIX_v1 applied=' + applied + ' skipped=' + skipped);
