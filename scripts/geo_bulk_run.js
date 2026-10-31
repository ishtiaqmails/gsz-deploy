'use strict';
/* scripts/geo_bulk_run.js — bulk-stage geo pages as DRAFT (location-first).
 *
 * Builds one page per (category x location) using the BASE landing intent, which
 * is the SEO-correct unit (one strong page per place, not thin intent variants).
 * Every page is staged DRAFT with gate scores + an index recommendation; NOTHING
 * is published. A human (or the admin) promotes DRAFT -> PUBLISHED later.
 *
 * Usage:
 *   node scripts/geo_bulk_run.js                 # category 'iptv', all enabled locations
 *   node scripts/geo_bulk_run.js iptv,vpns       # multiple categories
 *   node scripts/geo_bulk_run.js iptv 300        # cap at 300 pages
 *
 * Idempotent: existing slugs are skipped. Safe to re-run.
 */
const path = require('path');
const GSZ = process.env.GSZ_DIR || '/opt/gsz';
try { require(path.join(GSZ, 'node_modules', 'dotenv')).config({ path: path.join(GSZ, '.env') }); } catch (e) {}
const { Pool } = require(path.join(GSZ, 'node_modules', 'pg'));

const geoContent = require(path.join(GSZ, 'lib', 'geo_content'));
const geoBulk = require(path.join(GSZ, 'lib', 'geo_bulk'));
const gates = require(path.join(GSZ, 'lib', 'seo_gates'));
const storefront = require(path.join(GSZ, 'lib', 'storefront'));
let pricing = null; try { pricing = require(path.join(GSZ, 'lib', 'gsz_pricing')); } catch (e) {}

const CAT_ARG = (process.argv[2] || 'iptv').toLowerCase();
const LIMIT = Number(process.argv[3]) || 1000;

const pool = new Pool({
  host: process.env.DB_HOST, port: Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS
});

function depsFor(categoryId) {
  return {
    catalog: async () => {
      const rows = await storefront.loadProducts(pool, categoryId || null).catch(() => []);
      return rows.map(p => ({ id: p.id, name: p.name, slug: p.slug, description: p.descr, price: p.from, usd: p.from_usd, plans: p.plans, available: true }));
    },
    price: async (p, cc) => {
      const pkr = Number(p.price) || 0, usd = Number(p.usd) || 0;
      if (cc === 'PK') { let d = 'Rs ' + pkr.toLocaleString('en-US'); if (pricing && pricing.fmt) { try { d = pricing.fmt('PKR', pkr); } catch (e) {} } return { display: d, amount: pkr, currency: 'PKR', symbol: 'Rs ', usd }; }
      let d = '$' + usd; if (pricing && pricing.fmt) { try { d = pricing.fmt('USD', usd); } catch (e) {} }
      return { display: d, amount: usd, currency: 'USD', symbol: '$', usd };
    },
    rules: async () => [], siblings: async () => [], relatedCategories: async () => []
  };
}

(async () => {
  try {
    const settings = await storefront.loadSettings(pool).catch(() => ({}));
    const siteName = settings.site_name || 'Galaxy Subz × Zayron';

    // categories requested -> real rows
    const allCats = await storefront.loadCats(pool).catch(() => []);
    const wantSlugs = CAT_ARG.split(',').map(s => s.trim()).filter(Boolean);
    const cats = allCats.filter(c => wantSlugs.includes(String(c.slug).toLowerCase()));
    if (!cats.length) { console.log('No matching category for "' + CAT_ARG + '". Available: ' + allCats.map(c => c.slug).join(', ')); await pool.end(); process.exit(0); }

    // all enabled locations + byId map
    const locs = (await pool.query('SELECT * FROM geo_locations WHERE enabled AND seo_enabled')).rows;
    const byId = {}; locs.forEach(l => { byId[l.id] = l; });
    if (!locs.length) { console.log('No geo_locations found. Run geo_locations_load.js first.'); await pool.end(); process.exit(0); }

    // existing slugs to skip
    const existingSlugs = new Set((await pool.query('SELECT slug FROM geo_pages')).rows.map(r => r.slug));

    // plan: location-first, BASE intent only (no thin intent variants)
    const plan = geoBulk.planMatrix(
      { categories: cats.map(c => ({ id: c.id, slug: c.slug, name: c.name, demand: 0.8 })), locations: locs, intents: [{ key: 'BEST', slug: null }], byId, existingSlugs },
      { limit: LIMIT, includeBaseIntent: true });

    console.log('planned ' + plan.length + ' candidate pages (' + cats.map(c => c.slug).join(',') + ' x ' + locs.length + ' locations, base intent)');

    // assembleFor: build ctx from the candidate + byId, then assemble real content
    const depsCache = {};
    const assembleFor = async (cand) => {
      const country = byId[cand.country_id] || null, region = byId[cand.region_id] || null, city = byId[cand.city_id] || null;
      const target = city || region || country;
      const chain = [city, region, country].filter(Boolean);
      const ctx = {
        path: cand.slug, siteName, categoryName: cand.category_name, categorySlug: cand.category_slug, categoryId: cand.category_id,
        countryId: cand.country_id, regionId: cand.region_id, cityId: cand.city_id,
        country, region, city, chain, target,
        page_type: cand.page_type, intent: { key: cand.intent_key || 'BEST', slug: cand.intent_slug || null }
      };
      const dep = depsCache[cand.category_id] || (depsCache[cand.category_id] = depsFor(cand.category_id));
      return geoContent.assemble(ctx, dep);
    };

    const res = await geoBulk.stage(pool, plan, { assembleFor });

    // quality / index-recommendation summary
    const idx = res.drafts.filter(d => d.indexingRec === 'INDEX').length;
    const noidx = res.drafts.length - idx;
    const qs = res.drafts.map(d => d.quality).filter(n => n != null).sort((a, b) => a - b);
    const med = qs.length ? qs[Math.floor(qs.length / 2)] : 0;
    console.log('\n== staged (all DRAFT) ==');
    console.log('   created: ' + res.created + ', skipped (existing): ' + res.skipped);
    console.log('   would INDEX on publish: ' + idx + ', would NOINDEX (thin/dup): ' + noidx);
    console.log('   quality median: ' + med + (qs.length ? (' (min ' + qs[0] + ', max ' + qs[qs.length - 1] + ')') : ''));
    console.log('\nNothing is published. Review in admin (coming) or:');
    console.log("   SELECT slug,quality_score,status FROM geo_pages ORDER BY opportunity_score DESC LIMIT 20;");
    await pool.end();
  } catch (e) {
    console.error('bulk error:', e && e.message);
    try { await pool.end(); } catch (x) {}
    process.exit(1);
  }
})();
