'use strict';
/* IndexNow — instant "this URL changed" notifications to Bing, Yandex and the IndexNow network.
   Key is generated once and stored in wa_settings.indexnow_key; the key file is served by server.js
   at /<key>.txt. ping(pool, base, urls) submits up to 10k URLs. Fail-safe (never throws). */
const https = require('https');
let _key = null;

async function getKey(pool) {
  if (_key) return _key;
  try {
    const r = (await pool.query("SELECT value FROM wa_settings WHERE key='indexnow_key'")).rows[0];
    if (r && r.value && /^[a-f0-9]{16,64}$/i.test(r.value)) { _key = r.value; return _key; }
    const k = require('crypto').randomBytes(16).toString('hex');
    await pool.query("INSERT INTO wa_settings(key,value) VALUES('indexnow_key',$1) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value", [k]);
    _key = k; return k;
  } catch (e) { return null; }
}

function post(host, payload) {
  return new Promise(function (resolve) {
    try {
      const body = JSON.stringify(payload);
      const req = https.request({ host: host, path: '/indexnow', method: 'POST', timeout: 8000,
        headers: { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(body) } },
        function (res) { let d = ''; res.on('data', function (c) { d += c; }); res.on('end', function () { resolve({ status: res.statusCode, body: d.slice(0, 200) }); }); });
      req.on('error', function (e) { resolve({ status: 0, error: e.message }); });
      req.on('timeout', function () { req.destroy(); resolve({ status: 0, error: 'timeout' }); });
      req.write(body); req.end();
    } catch (e) { resolve({ status: 0, error: e.message }); }
  });
}

// ping(pool, base, urls) -> submits to IndexNow. base e.g. 'https://galaxyzayron.store'
async function ping(pool, base, urls) {
  try {
    if (!Array.isArray(urls)) urls = [urls];
    urls = urls.filter(Boolean).slice(0, 10000);
    if (!urls.length) return { status: 0, error: 'no urls' };
    const key = await getKey(pool); if (!key) return { status: 0, error: 'no key' };
    const b = String(base || '').replace(/\/+$/, '');
    const host = b.replace(/^https?:\/\//, '').replace(/\/.*$/, '');
    const payload = { host: host, key: key, keyLocation: b + '/' + key + '.txt', urlList: urls };
    return await post('api.indexnow.org', payload);
  } catch (e) { return { status: 0, error: e.message }; }
}

module.exports = { getKey, ping };
