'use strict';
/* Standalone re-embed: builds the fresh corpus from the live DB and pushes it to gsz-sem.
   Used to recover the semantic index after a sidecar restart, without touching the store app. */
const http = require('http');
const ROOT = '/opt/gsz';
require(ROOT + '/node_modules/dotenv').config({ path: ROOT + '/.env' });
const { Pool } = require(ROOT + '/node_modules/pg');
const kb = require(ROOT + '/lib/supportkb');
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

(async () => {
  kb.invalidate();
  const k = await kb.get(pool, { force: true });
  const corpus = kb.corpus(k);
  const data = JSON.stringify(corpus);
  console.log('corpus: ' + corpus.products.length + ' products, ' + corpus.faqs.length + ' faqs, ' + corpus.intents.length + ' intents (' + Math.round(Buffer.byteLength(data) / 1024) + ' KB)');
  await new Promise((resolve) => {
    const r = http.request({ host: '127.0.0.1', port: Number(process.env.SEM_PORT || 3910), path: '/reindex', method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } },
      (res) => { let s = ''; res.on('data', d => s += d); res.on('end', () => { console.log('reindex result: ' + s); resolve(); }); });
    r.on('error', (e) => { console.log('reindex ERROR: ' + e.message); resolve(); });
    r.setTimeout(90000, () => { console.log('reindex timed out'); try { r.destroy(); } catch (e) {} resolve(); });
    r.write(data); r.end();
  });
  await pool.end();
})().catch(e => { console.error('FAIL ' + e.message); process.exit(1); });
