#!/usr/bin/env bash
# stepReviewsR1.sh — extend the reviews table for customer-submitted, per-product, moderated reviews.
# Additive + idempotent (IF NOT EXISTS). No app restart needed (schema only).
set -euo pipefail
R=/opt/gsz
node -e "
const R='/opt/gsz'; require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const { Pool } = require(R+'/node_modules/pg');
const p = new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async () => {
  await p.query('ALTER TABLE reviews ADD COLUMN IF NOT EXISTS product_id integer');
  await p.query('ALTER TABLE reviews ADD COLUMN IF NOT EXISTS customer_id integer');
  await p.query('ALTER TABLE reviews ADD COLUMN IF NOT EXISTS verified boolean NOT NULL DEFAULT false');
  await p.query('ALTER TABLE reviews ADD COLUMN IF NOT EXISTS title text');
  await p.query('CREATE INDEX IF NOT EXISTS reviews_product_idx ON reviews(product_id)');
  const r = await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name='reviews' ORDER BY ordinal_position\");
  console.log('   reviews columns: ' + r.rows.map(x => x.column_name).join(', '));
  await p.end();
})().catch(e => { console.error(e.message); process.exit(1); });
"
echo "DONE — reviews table ready (product_id, customer_id, verified, title). Existing reviews untouched (site-wide, product_id NULL)."
