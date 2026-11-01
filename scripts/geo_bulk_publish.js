'use strict';
/* scripts/geo_bulk_publish.js — publish a large batch of geo pages in the background.
 * Reads a JSON array of geo_pages ids from the file passed as argv[2], publishes each via
 * geo_publish.publish (the gate decides index/noindex), then removes the file. Used by the
 * admin "Publish (all matching)" bulk action when the batch is too big to do inside a request. */
const path = require('path');
const fs = require('fs');
const GSZ = process.env.GSZ_DIR || '/opt/gsz';
try { require(path.join(GSZ, 'node_modules', 'dotenv')).config({ path: path.join(GSZ, '.env') }); } catch (e) {}
const { Pool } = require(path.join(GSZ, 'node_modules', 'pg'));
const geoPublish = require(path.join(GSZ, 'lib', 'geo_publish'));
const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT) || 5432, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

(async () => {
  const file = process.argv[2];
  if (!file) { console.error('no ids file'); process.exit(1); }
  let ids = [];
  try { ids = JSON.parse(fs.readFileSync(file, 'utf8')) || []; } catch (e) { console.error('bad ids file'); process.exit(1); }
  console.log('bulk publish: ' + ids.length + ' pages');
  let ok = 0, fail = 0;
  for (const id of ids) {
    try { const r = await geoPublish.publish(pool, id); if (r && r.ok) ok++; else fail++; } catch (e) { fail++; }
    if (ok && ok % 200 === 0) console.log('   ...' + ok + ' published');
  }
  console.log('done: ' + ok + ' published, ' + fail + ' skipped');
  try { fs.unlinkSync(file); } catch (e) {}
  await pool.end();
})().catch(async e => { console.error('error:', e && e.message); try { await pool.end(); } catch (x) {} process.exit(1); });
