'use strict';
/* Content loader — upserts SEO descriptions + curated FAQs for products, then re-embeds the
   semantic brain so the bot instantly knows the new knowledge. Reads a JSON array of
   { id?, slug?, short?, long?, faqs:[{q,a}] }. Real content only — nothing invented here;
   the JSON is the source of truth. Idempotent: re-running replaces a product's FAQs cleanly. */
const fs = require('fs'), http = require('http');
const ROOT = '/opt/gsz';
require(ROOT + '/node_modules/dotenv').config({ path: ROOT + '/.env' });
const { Pool } = require(ROOT + '/node_modules/pg');

const file = process.argv[2];
if (!file) { console.error('usage: node load_content.js <content.json>'); process.exit(1); }
const items = JSON.parse(fs.readFileSync(file, 'utf8'));
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

(async () => {
  let prods = 0, faqs = 0;
  for (const it of items) {
    let id = it.id || null;
    if (!id && it.slug) { const r = await pool.query('SELECT id FROM products WHERE slug=$1', [it.slug]); id = (r.rows[0] || {}).id || null; }
    if (!id) { console.log('  SKIP (not found): ' + (it.slug || it.name || '?')); continue; }
    await pool.query('UPDATE products SET short_desc=COALESCE($2,short_desc), long_desc=COALESCE($3,long_desc) WHERE id=$1',
      [id, it.short || null, it.long || null]);
    prods++;
    if (Array.isArray(it.faqs)) {
      await pool.query('DELETE FROM product_faqs WHERE product_id=$1', [id]);
      let s = 0;
      for (const f of it.faqs) { if (!f || !f.q || !f.a) continue; await pool.query('INSERT INTO product_faqs(product_id, q, a, sort) VALUES($1,$2,$3,$4)', [id, f.q, f.a, s++]); faqs++; }
    }
    console.log('  ✓ ' + (it.slug || id) + ' (' + (Array.isArray(it.faqs) ? it.faqs.length : 0) + ' faqs)');
  }
  console.log('updated ' + prods + ' products, ' + faqs + ' faqs');

  // re-embed the semantic brain with the fresh corpus (best-effort)
  try {
    const kb = require(ROOT + '/lib/supportkb');
    kb.invalidate();
    const k = await kb.get(pool, { force: true });
    const corpus = kb.corpus(k);
    const data = JSON.stringify(corpus);
    await new Promise((resolve) => {
      const r = http.request({ host: '127.0.0.1', port: Number(process.env.SEM_PORT || 3910), path: '/reindex', method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } },
        (res) => { let s = ''; res.on('data', d => s += d); res.on('end', () => { console.log('semantic reindex: ' + s); resolve(); }); });
      r.on('error', (e) => { console.log('semantic reindex skipped (sidecar down?): ' + e.message); resolve(); });
      r.setTimeout(20000, () => { try { r.destroy(); } catch (e) {} resolve(); });
      r.write(data); r.end();
    });
  } catch (e) { console.log('semantic reindex skipped: ' + e.message); }

  await pool.end();
  console.log('CONTENT LOAD OK');
})().catch(e => { console.error('CONTENT LOAD FAIL ' + e.message); process.exit(1); });
