'use strict';
/* patch_homeseo.js — give the HOMEPAGE a proper title + full SEO (in-place, idempotent).
   The shared head already renders title / metaDescription / canonicalUrl / ogTags / jsonLd when
   provided; the home route (server.js) passed none. This threads them into homeData's result `d`. */
const fs = require('fs');
const GSZ = '/opt/gsz';
const f = GSZ + '/server.js';
let s = fs.readFileSync(f, 'utf8');

if (s.indexOf('HOME_SEO_v1') !== -1) { console.log('HOME_SEO already present — skip'); process.exit(0); }

const anchor = "try { const d = await homeData(); res.render('home', d); }";
if (s.indexOf(anchor) === -1) throw new Error('home render anchor not found');

const repl =
  "try {\n" +
  "      const d = await homeData();\n" +
  "      /* HOME_SEO_v1 — homepage title + meta + Open Graph/Twitter + Organization/WebSite schema */\n" +
  "      const _sn = d.siteName || 'Galaxy Subz \\u00d7 Zayron';\n" +
  "      const _base = 'https://galaxyzayron.store';\n" +
  "      const _img = _base + '/static/img/' + (d.logoFile || 'logo.png');\n" +
  "      const _esc = function (x) { return String(x == null ? '' : x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\"/g, '&quot;'); };\n" +
  "      d.title = _sn + ' \\u2014 IPTV & Premium Digital Subscriptions';\n" +
  "      d.metaDescription = 'Galaxy Subz \\u00d7 Zayron \\u2014 buy premium IPTV, streaming and digital subscriptions at the best prices. Instant automated delivery, real WhatsApp support, and free IPTV trials.';\n" +
  "      d.canonicalUrl = _base + '/';\n" +
  "      d.ogTags = '<meta property=\"og:type\" content=\"website\">'\n" +
  "        + '<meta property=\"og:site_name\" content=\"' + _esc(_sn) + '\">'\n" +
  "        + '<meta property=\"og:title\" content=\"' + _esc(d.title) + '\">'\n" +
  "        + '<meta property=\"og:description\" content=\"' + _esc(d.metaDescription) + '\">'\n" +
  "        + '<meta property=\"og:url\" content=\"' + _esc(d.canonicalUrl) + '\">'\n" +
  "        + '<meta property=\"og:image\" content=\"' + _esc(_img) + '\">'\n" +
  "        + '<meta name=\"twitter:card\" content=\"summary_large_image\">'\n" +
  "        + '<meta name=\"twitter:title\" content=\"' + _esc(d.title) + '\">'\n" +
  "        + '<meta name=\"twitter:description\" content=\"' + _esc(d.metaDescription) + '\">'\n" +
  "        + '<meta name=\"twitter:image\" content=\"' + _esc(_img) + '\">';\n" +
  "      const _ld = { '@context': 'https://schema.org', '@graph': [\n" +
  "        { '@type': 'Organization', '@id': _base + '/#org', name: _sn, url: _base + '/', logo: _img, description: d.metaDescription },\n" +
  "        { '@type': 'WebSite', '@id': _base + '/#site', name: _sn, url: _base + '/', publisher: { '@id': _base + '/#org' } }\n" +
  "      ] };\n" +
  "      d.jsonLd = JSON.stringify(_ld).replace(/</g, '\\\\u003c');\n" +
  "      res.render('home', d);\n" +
  "    }";

s = s.replace(anchor, repl);
fs.writeFileSync(f, s);
console.log('HOME_SEO PATCH applied');
