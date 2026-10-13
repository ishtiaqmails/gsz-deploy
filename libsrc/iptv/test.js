'use strict';
/* IPTV Library Engine — standalone proof harness. Runs on the VPS against ONE real panel so we see
   the true library size and can design storage to fit. Uses only Node built-ins (http/https/readline/
   fs/zlib) — no app deps, nothing written to disk, credentials live only in the argv on your server.

   Auto:    node test.js --auto SKU-00030          (engine sources creds itself via gsz-api —
                                                    orders-first, free-trial fallback; no creds typed)
   Xtream:  node test.js http://panel.host:port  USERNAME  PASSWORD
   M3U:     node test.js --m3u "http://panel.host/get.php?username=U&password=P&type=m3u_plus"

   Prints: auth/server info, raw vs cleaned counts, per-category breakdown, a few sample cleaned
   names, timing, and a gzipped-storage estimate for the snapshot we'd keep. */
const zlib = require('zlib');
const fetch = require('./fetch');
const m3u = require('./m3u');
const clean = require('./clean');
const credsource = require('./credsource');

function human(n) { return n >= 1e6 ? (n / 1e6).toFixed(2) + 'M' : n >= 1e3 ? (n / 1e3).toFixed(1) + 'k' : String(n); }
function kb(bytes) { return bytes >= 1048576 ? (bytes / 1048576).toFixed(2) + ' MB' : (bytes / 1024).toFixed(1) + ' KB'; }
function ms(t) { return (Date.now() - t) + ' ms'; }

function snapshotSize(enh) {
  // what we'd actually persist: clean entries only (name, key, quality, category, variants, episodes)
  const pack = k => enh[k].items.map(i => [i.name, i.quality.join('/'), i.category, i.variants, i.episodes || 0]);
  const json = JSON.stringify({ live: pack('live'), vod: pack('vod'), series: pack('series') });
  const gz = zlib.gzipSync(Buffer.from(json), { level: 9 });
  return { raw: Buffer.byteLength(json), gz: gz.length };
}

function report(label, c) {
  console.log('\n  ' + label + ':  ' + human(c.raw) + ' raw  ->  ' + human(c.total) + ' clean  (' + human(c.dupes) + ' dupes folded, ' + human(c.adult) + ' adult hidden)');
  const cats = Object.entries(c.categories).sort((a, b) => b[1] - a[1]);
  console.log('    categories: ' + cats.map(([k, v]) => k + ' ' + human(v)).join('  ·  '));
  console.log('    samples:    ' + c.items.slice(0, 6).map(i => i.name + (i.quality.length ? ' [' + i.quality.join('/') + ']' : '')).join('  |  '));
}

(async () => {
  const args = process.argv.slice(2);
  if (!args.length) { console.error('usage:\n  node test.js <host> <user> <pass>\n  node test.js --m3u <url>'); process.exit(1); }

  let lib, src;
  const t0 = Date.now();
  if (args[0] === '--auto') {
    src = 'Auto (gsz-api)';
    const sku = args[1];
    if (!sku) { console.error('usage: node test.js --auto <SKU>'); process.exit(1); }
    const { base, key } = credsource.loadEnv();
    console.log('gsz-api: ' + (base || '(none found)') + (key ? '  key:' + key.slice(0, 4) + '…' : '  (no key)'));
    console.log('Resolving read-only credentials for ' + sku + ' (orders-first, free-trial fallback)…');
    const cr = await credsource.resolve(sku, { hours: 24, trialTimeoutMs: 150000 });
    if (!cr.ok) { console.error('Could not source credentials: ' + cr.error + (cr.detail ? '  (' + cr.detail + ')' : '')); process.exit(1); }
    console.log('  got creds via ' + cr.source + ' — ' + cr.note + '  (host=' + cr.host + ' user=' + cr.username + ')');
    const inf = await fetch.info(cr.host, cr.username, cr.password);
    if (inf.ok && inf.user_info) console.log('  auth OK · status=' + (inf.user_info.status || '?') + (inf.user_info.exp_date ? ' · expires=' + new Date(inf.user_info.exp_date * 1000).toISOString().slice(0, 10) : ''));
    console.log('Pulling full library…');
    const tf = Date.now();
    lib = await fetch.fetchAll(cr.host, cr.username, cr.password);
    console.log('  fetched in ' + ms(tf) + (Object.values(lib.errors || {}).some(Boolean) ? '  (errors: ' + JSON.stringify(lib.errors) + ')' : ''));
  } else if (args[0] === '--m3u') {
    src = 'M3U';
    console.log('Fetching M3U playlist (streaming)…');
    const r = await m3u.fetchM3U(args[1], 180000);
    if (!r.ok) { console.error('M3U fetch failed: ' + r.error); process.exit(1); }
    console.log('  scanned ' + human(r.scanned) + ' playlist entries in ' + ms(t0));
    lib = r;
  } else {
    src = 'Xtream';
    const [host, user, pass] = args;
    console.log('Checking credentials…');
    const inf = await fetch.info(host, user, pass);
    if (!inf.ok) { console.error('Auth/reachability failed: ' + inf.error + (inf.sample ? '  (' + inf.sample + ')' : '')); process.exit(1); }
    const ui = inf.user_info || {}, si = inf.server_info || {};
    console.log('  auth OK · status=' + (ui.status || '?') + ' · active_cons=' + (ui.active_cons || '?') + '/' + (ui.max_connections || '?') + (ui.exp_date ? ' · expires=' + new Date(ui.exp_date * 1000).toISOString().slice(0, 10) : '') + (si.url ? ' · server=' + si.url : ''));
    console.log('Pulling full library (live + vod + series + categories)…');
    const tf = Date.now();
    lib = await fetch.fetchAll(host, user, pass);
    console.log('  fetched in ' + ms(tf) + (Object.values(lib.errors || {}).some(Boolean) ? '  (errors: ' + JSON.stringify(lib.errors) + ')' : ''));
  }

  const te = Date.now();
  const enh = clean.enhance(lib);
  console.log('  enhanced/de-duped in ' + ms(te));

  report('LIVE TV', enh.live);
  report('MOVIES (VOD)', enh.vod);
  report('SERIES', enh.series);
  console.log('\n  SERIES episodes counted: ' + human(enh.counts.episodes));

  const sz = snapshotSize(enh);
  const totalClean = enh.counts.live + enh.counts.vod + enh.counts.series;
  const totalRaw = enh.rawCounts.live + enh.rawCounts.vod + enh.rawCounts.series;
  console.log('\n  ── STORAGE ──');
  console.log('    clean library total: ' + human(totalClean) + ' titles (from ' + human(totalRaw) + ' raw rows)');
  console.log('    snapshot JSON: ' + kb(sz.raw) + '  ->  gzipped: ' + kb(sz.gz) + '  (this is what we persist per server)');
  console.log('\n  total wall time: ' + ms(t0) + '  (source: ' + src + ')');
  console.log('\nDONE');
})().catch(e => { console.error('CRASH ' + (e && e.stack || e)); process.exit(1); });
