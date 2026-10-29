'use strict';
/* Auto-submit indexable URLs to IndexNow (Bing / Yandex / Seznam / partners) on boot + daily.
   Source of truth = the site's own /sitemap.xml, so any new product, category or content
   page is picked up automatically with no extra wiring. Fail-safe: never throws, never blocks. */
const http = require('http');
const indexnow = require('./indexnow');

function fetchSitemap(port) {
  return new Promise(function (resolve) {
    try {
      const req = http.request({ host: '127.0.0.1', port: port || 3900, path: '/sitemap.xml', method: 'GET' }, function (res) {
        let d = ''; res.setEncoding('utf8'); res.on('data', function (c) { d += c; }); res.on('end', function () { resolve(d); });
      });
      req.on('error', function () { resolve(''); });
      req.setTimeout(8000, function () { try { req.destroy(); } catch (e) {} resolve(''); });
      req.end();
    } catch (e) { resolve(''); }
  });
}

module.exports.start = function (pool, opts) {
  opts = opts || {};
  const base = opts.base || 'https://galaxyzayron.store';
  const port = opts.port || 3900;
  const everyMs = Number(opts.everyMs) > 0 ? Number(opts.everyMs) : 24 * 60 * 60 * 1000;
  let running = false;
  async function run(why) {
    if (running) return; running = true;
    try {
      const xml = await fetchSitemap(port);
      const urls = (String(xml).match(/<loc>([^<]+)<\/loc>/g) || [])
        .map(function (m) { return m.replace(/<\/?loc>/g, '').trim(); })
        .filter(function (u) { return /^https?:\/\//.test(u); });
      if (!urls.length) { console.log('[indexnow] ' + why + ': no URLs found in sitemap'); return; }
      const r = await indexnow.ping(pool, base, urls);
      console.log('[indexnow] ' + why + ': submitted ' + urls.length + ' URLs (status ' + (r && r.status) + ')');
    } catch (e) { console.error('[indexnow] ' + why + ' failed:', e && e.message); }
    finally { running = false; }
  }
  setTimeout(function () { run('startup'); }, 15000); // once, after the server is up
  const t = setInterval(function () { run('daily'); }, everyMs);
  if (t && t.unref) t.unref();
  return { runNow: function () { return run('manual'); } };
};
