'use strict';
/* #82 — regenerate every product slug from its clean product NAME (no id/plan/date tail),
   e.g. "Opplex TV IPTV" -> opplex-tv-iptv. Records a 301 redirect old->new in cs_redirects
   so every existing link stays alive. Also reports any product with zero plans.
   Idempotent: a product already on its clean slug is skipped (new==old => no change, no redirect).
   Runs inside one transaction — partial failure rolls the whole thing back. Read-only until COMMIT. */
const path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node migrate_slugs.js <ROOT>'); process.exit(1); }
require(path.join(ROOT, 'node_modules/dotenv')).config({ path: path.join(ROOT, '.env') });
const { Pool } = require(path.join(ROOT, 'node_modules/pg'));
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

function slugify(s) { return String(s == null ? '' : s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, ''); }

(async () => {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    const prods = (await c.query('SELECT id, name, slug FROM products ORDER BY id')).rows;

    // 1) compute unique clean slug per product (collision-safe, deterministic by id order)
    const used = new Set(); const plan = [];
    for (const p of prods) {
      let base = slugify(p.name) || ('product-' + p.id);
      let slug = base, n = 1;
      while (used.has(slug)) { n++; slug = base + '-' + n; }
      used.add(slug);
      plan.push({ id: p.id, name: p.name, old: p.slug, next: slug });
    }

    // 2) apply changes + write redirects
    let changed = 0, redirects = 0;
    for (const x of plan) {
      if (x.next === x.old) continue;
      await c.query('UPDATE products SET slug=$1 WHERE id=$2', [x.next, x.id]);
      const from = '/product/' + x.old, to = '/product/' + x.next;
      await c.query('DELETE FROM cs_redirects WHERE from_path=$1', [from]);
      await c.query('INSERT INTO cs_redirects(from_path, to_path, code) VALUES($1,$2,301)', [from, to]);
      changed++; redirects++;
      console.log('  ' + x.old + '  ->  ' + x.next);
    }

    // 3) plan-coverage check (report only)
    const noplans = (await c.query(
      'SELECT p.id, p.name FROM products p WHERE NOT EXISTS (SELECT 1 FROM product_plans pp WHERE pp.product_id=p.id) ORDER BY p.id'
    )).rows;

    await c.query('COMMIT');
    console.log('');
    console.log('slugs changed : ' + changed + ' / ' + prods.length);
    console.log('301 redirects : ' + redirects + ' written (old link -> new slug)');
    if (noplans.length) { console.log('!! products with NO plans (' + noplans.length + '): ' + noplans.map(r => r.id + ':' + r.name).join(', ')); }
    else { console.log('plan coverage : OK — every product has at least one plan'); }
    console.log('SLUGMIGRATE OK');
  } catch (e) {
    try { await c.query('ROLLBACK'); } catch (_) {}
    console.error('SLUGMIGRATE FAIL ' + e.message);
    process.exit(1);
  } finally { c.release(); await pool.end(); }
})();
