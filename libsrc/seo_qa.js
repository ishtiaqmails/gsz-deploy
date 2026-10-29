'use strict';
/* On-demand SEO QA. Crawls the live sitemap's URLs (via localhost) and reports issues:
   missing/short/long/duplicate title, missing/short/long/duplicate meta description,
   H1 count != 1, missing canonical, noindex, invalid JSON-LD, images missing alt, non-200 status.
   Read-only. Run:  node /opt/gsz/lib/seo_qa.js [port]  */
const http = require('http');
const PORT = parseInt(process.argv[2], 10) || 3900;

function get(path) {
  return new Promise(function (resolve) {
    const r = http.request({ host: '127.0.0.1', port: PORT, path: path, method: 'GET', headers: { 'User-Agent': 'seo-qa' } }, function (x) {
      let d = ''; x.setEncoding('utf8'); x.on('data', function (c) { d += c; }); x.on('end', function () { resolve({ status: x.statusCode, body: d }); });
    });
    r.on('error', function () { resolve({ status: 0, body: '' }); });
    r.setTimeout(15000, function () { try { r.destroy(); } catch (e) {} resolve({ status: 0, body: '' }); });
    r.end();
  });
}
function first(re, s) { const m = s.match(re); return m ? m[1].trim() : ''; }
function count(re, s) { return (s.match(re) || []).length; }

(async function () {
  const sm = await get('/sitemap.xml');
  const locs = (sm.body.match(/<loc>([^<]+)<\/loc>/g) || []).map(function (m) { return m.replace(/<\/?loc>/g, '').trim(); });
  const paths = locs.map(function (u) { return u.replace(/^https?:\/\/[^/]+/, '') || '/'; });
  if (!paths.length) { console.log('No URLs in sitemap (is the site up on port ' + PORT + '?).'); return; }

  const titles = {}, descs = {}; let checked = 0; const issues = [];
  for (const p of paths) {
    const r = await get(p);
    const b = r.body || '';
    const bad = [];
    if (r.status !== 200) bad.push('HTTP ' + r.status);
    const title = first(/<title>([^<]*)<\/title>/i, b);
    if (!title) bad.push('no <title>'); else { if (title.length < 10) bad.push('title short (' + title.length + ')'); if (title.length > 65) bad.push('title long (' + title.length + ')'); (titles[title] = titles[title] || []).push(p); }
    const desc = first(/<meta name="description" content="([^"]*)"/i, b);
    if (!desc) bad.push('no meta description'); else { if (desc.length < 50) bad.push('desc short (' + desc.length + ')'); if (desc.length > 165) bad.push('desc long (' + desc.length + ')'); (descs[desc] = descs[desc] || []).push(p); }
    const h1 = count(/<h1[\s>]/gi, b);
    if (h1 !== 1) bad.push('H1 count = ' + h1);
    if (!/rel="canonical"/i.test(b)) bad.push('no canonical');
    if (/<meta name="robots"[^>]*noindex/i.test(b)) bad.push('noindex');
    const lds = b.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/gi) || [];
    let ldBad = 0; lds.forEach(function (x) { try { JSON.parse(x.replace(/<\/?script[^>]*>/gi, '')); } catch (e) { ldBad++; } });
    if (lds.length === 0) bad.push('no JSON-LD'); else if (ldBad) bad.push(ldBad + ' invalid JSON-LD');
    const imgs = b.match(/<img\b[^>]*>/gi) || []; const noAlt = imgs.filter(function (t) { return !/\balt=/.test(t); }).length;
    if (noAlt) bad.push(noAlt + ' img no-alt');
    if (bad.length) issues.push({ p: p, bad: bad });
    checked++;
  }
  const dupT = Object.keys(titles).filter(function (t) { return titles[t].length > 1; });
  const dupD = Object.keys(descs).filter(function (d) { return descs[d].length > 1; });

  console.log('\n==== SEO QA — ' + checked + ' pages crawled ====');
  console.log('Pages with issues: ' + issues.length);
  console.log('Duplicate titles: ' + dupT.length + ' | Duplicate meta descriptions: ' + dupD.length);
  console.log('\n-- issues (first 25) --');
  issues.slice(0, 25).forEach(function (x) { console.log('  ' + x.p + '  ->  ' + x.bad.join(', ')); });
  if (dupT.length) { console.log('\n-- duplicate titles (first 5) --'); dupT.slice(0, 5).forEach(function (t) { console.log('  "' + t.slice(0, 50) + '" x' + titles[t].length); }); }
  if (dupD.length) { console.log('\n-- duplicate descriptions (first 5) --'); dupD.slice(0, 5).forEach(function (d) { console.log('  "' + d.slice(0, 50) + '..." x' + descs[d].length); }); }
  console.log('\n' + (issues.length ? 'Review the issues above.' : 'Clean — no SEO issues found.'));
})().catch(function (e) { console.error('seo_qa error:', e.message); });
