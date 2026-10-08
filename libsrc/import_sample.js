'use strict';
/* Import one content-package JSON file into cs_posts (published). Upserts by slug. */
require('dotenv').config({ path: process.env.GSZ_ENV || '/opt/gsz/.env' });
const { Pool } = require('pg');
const B = require('/opt/gsz/lib/csblocks');
const fs = require('fs');
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });
const FILE = process.argv[2];
const PREFIX = { article: 'blog', news: 'news', guide: 'guides', tutorial: 'tutorials', review: 'reviews', comparison: 'comparisons', buying_guide: 'buying-guides', troubleshooting: 'troubleshooting', faq: 'knowledge', knowledge: 'knowledge' };
(async () => {
  const pkg = JSON.parse(fs.readFileSync(FILE, 'utf8'));
  const r = B.normalizePackage(pkg);
  if (r.warnings && r.warnings.length) console.log('    warnings: ' + JSON.stringify(r.warnings));
  if (!r.ok) { console.error('IMPORT INVALID: ' + JSON.stringify(r.errors)); process.exit(2); }
  const p = r.post;
  const blocks = JSON.stringify(p.blocks), seo = JSON.stringify(p.seo);
  const ex = (await pool.query('SELECT id FROM cs_posts WHERE slug=$1', [p.slug])).rows[0];
  if (ex) {
    await pool.query("UPDATE cs_posts SET type=$1,title=$2,excerpt=$3,blocks=$4,featured_image=$5,reading_time=$6,seo=$7,status='published',published_at=COALESCE(published_at,now()),updated_at=now() WHERE id=$8",
      [p.type, p.title, p.excerpt, blocks, p.featured_image, p.reading_time, seo, ex.id]);
    console.log('    updated: ' + p.slug);
  } else {
    await pool.query("INSERT INTO cs_posts(type,slug,title,excerpt,blocks,featured_image,reading_time,seo,status,author_id,published_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,'published',1,now())",
      [p.type, p.slug, p.title, p.excerpt, blocks, p.featured_image, p.reading_time, seo]);
    console.log('    inserted: ' + p.slug);
  }
  const prefix = PREFIX[p.type] || 'blog';
  console.log('    live at: /' + prefix + '/' + p.slug + '  (' + p.type + ', ' + p.reading_time + ' min, ' + p.blocks.length + ' blocks)');
  await pool.end();
})().catch(function (e) { console.error('IMPORT FAILED: ' + e.message); process.exit(3); });
