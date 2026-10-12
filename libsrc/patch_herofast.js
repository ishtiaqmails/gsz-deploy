'use strict';
/* Hero fast-load markup:
   1) home.ejs <picture> — serve WebP first (mobile WebP for small screens, desktop WebP
      otherwise), PNG as fallback; first slide gets fetchpriority=high + eager, the rest
      lazy; decoding=async everywhere.
   2) store_top.ejs <head> — preload the first hero banner (the WebP, responsive) so it
      starts downloading at parse, before CSS/fonts. Guarded to the home page (heroCats).
   Content-only anchors (no leading-whitespace dependency). Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_herofast.js <ROOT>'); process.exit(1); }

/* ---- home.ejs ---- */
(function () {
  const file = path.join(ROOT, 'views/home.ejs');
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf('/*heroFast*/') >= 0) { console.log('skip (already): hero fast markup'); return; }

  const M = '<% if (bm.mobile) { %><source media="(max-width:720px)" srcset="/static/img/<%= bm.mobile %>"><% } %>';
  if (s.indexOf(M) < 0) throw new Error('ANCHOR MISS: hero mobile source');
  s = s.replace(M,
    '<% if (bm.mobile) { %><source media="(max-width:720px)" type="image/webp" srcset="/static/img/<%= bm.mobile.replace(/\\.(png|jpe?g)$/i,\'.webp\') %>"><source media="(max-width:720px)" srcset="/static/img/<%= bm.mobile %>"><% } %>');

  const I = '<img src="/static/img/<%= bm.desktop || bm.mobile %>" alt="<%= c.name %>">';
  if (s.indexOf(I) < 0) throw new Error('ANCHOR MISS: hero img');
  s = s.replace(I,
    '<source type="image/webp" srcset="/static/img/<%= (bm.desktop||bm.mobile).replace(/\\.(png|jpe?g)$/i,\'.webp\') %>">' +
    '<img src="/static/img/<%= bm.desktop || bm.mobile %>" alt="<%= c.name %>"<%- i===0?\' fetchpriority="high" loading="eager"\':\' loading="lazy"\' %> decoding="async"><%/*heroFast*/%>');

  fs.writeFileSync(file, s);
  console.log('hero markup: webp-first + priority OK');
})();

/* ---- store_top.ejs head preload ---- */
(function () {
  const file = path.join(ROOT, 'views/partials/store_top.ejs');
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf('/*heroPreload*/') >= 0) { console.log('skip (already): hero preload'); return; }

  const A = '<link rel="icon" href="/static/img/<%= logoFile %>">';
  if (s.indexOf(A) < 0) throw new Error('ANCHOR MISS: favicon link');
  const P = A + '\n' +
    '<%/*heroPreload*/ if (typeof heroCats!==\'undefined\' && heroCats && heroCats.length) { var _hc=heroCats[0]; var _hbm=(typeof bannerMap!==\'undefined\'&&bannerMap[_hc.slug])||{}; var _pd=_hbm.desktop||_hbm.mobile, _pm=_hbm.mobile||_hbm.desktop; var _pw=function(f){return f?f.replace(/\\.(png|jpe?g)$/i,\'.webp\'):f;}; %>' +
    '<% if(_pd){ %><link rel="preload" as="image" href="/static/img/<%= _pw(_pd) %>" media="(min-width:721px)" fetchpriority="high"><% } %>' +
    '<% if(_pm){ %><link rel="preload" as="image" href="/static/img/<%= _pw(_pm) %>" media="(max-width:720px)" fetchpriority="high"><% } %>' +
    '<% } %>';
  s = s.replace(A, P);

  fs.writeFileSync(file, s);
  console.log('hero preload link OK');
})();

console.log('HEROFAST OK');
