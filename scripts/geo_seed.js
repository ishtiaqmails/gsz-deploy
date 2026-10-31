'use strict';
/* scripts/geo_seed.js — seed ONE/few demo geo pages so the engine is visible for review.
 *
 * Safe + reversible:
 *   - Upserts a couple of geo_locations (Pakistan, Peshawar) — additive.
 *   - Builds each page from REAL data (live IPTV products via storefront + real
 *     locale) through the content assembler + gates.
 *   - Inserts geo_pages as status='PUBLISHED' but indexing_status='NOINDEX', so
 *     the owner can view the URL live while search engines are told to ignore it
 *     until the design is approved. ON CONFLICT(slug) updates in place.
 *
 * Run:  node scripts/geo_seed.js            (from /opt/gsz, after files are copied)
 * Undo: UPDATE geo_pages SET status='ARCHIVED' WHERE slug IN (...);  (printed at end)
 *
 * Idempotent. Never throws fatally on a single page; logs and continues.
 */
const path = require('path');
const GSZ = process.env.GSZ_DIR || '/opt/gsz';
try { require(path.join(GSZ, 'node_modules', 'dotenv')).config({ path: path.join(GSZ, '.env') }); } catch (e) {}
const { Pool } = require(path.join(GSZ, 'node_modules', 'pg'));

const geoContent = require(path.join(GSZ, 'lib', 'geo_content'));
const gates = require(path.join(GSZ, 'lib', 'seo_gates'));
const storefront = require(path.join(GSZ, 'lib', 'storefront'));
let pricing = null; try { pricing = require(path.join(GSZ, 'lib', 'gsz_pricing')); } catch (e) {}

const pool = new Pool({
  host: process.env.DB_HOST, port: Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS
});

const SITE_URL = (process.env.SITE_URL || 'https://galaxyzayron.store').replace(/\/+$/, '');

async function upsertLocation(loc) {
  const r = await pool.query(
    `INSERT INTO geo_locations(type,name,slug,country_code,parent_id,currency,currency_symbol,demonym,languages,enabled,seo_enabled,indexable,priority)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,TRUE,TRUE,TRUE,$10)
     ON CONFLICT (type,slug) DO UPDATE SET
       country_code=COALESCE(EXCLUDED.country_code,geo_locations.country_code),
       parent_id=COALESCE(EXCLUDED.parent_id,geo_locations.parent_id),
       currency=COALESCE(EXCLUDED.currency,geo_locations.currency),
       demonym=COALESCE(EXCLUDED.demonym,geo_locations.demonym),
       languages=EXCLUDED.languages, updated_at=now()
     RETURNING *`,
    [loc.type, loc.name, loc.slug, loc.country_code || null, loc.parent_id || null,
     loc.currency || null, loc.currency_symbol || null, loc.demonym || null,
     JSON.stringify(loc.languages || []), loc.priority || 100]);
  return r.rows[0];
}

function depsFor(categoryId) {
  return {
    catalog: async () => {
      const rows = await storefront.loadProducts(pool, categoryId || null).catch(() => []);
      return rows.map(p => ({
        id: p.id, name: p.name, slug: p.slug, description: p.descr,
        price: p.from, usd: p.from_usd, plans: p.plans, available: true
      }));
    },
    price: async (p, cc) => {
      const pkr = p.price, usd = p.usd;
      if (pricing && pricing.resolve) {
        try { const q = await pricing.resolve({ pkr, usd, price: pkr, from: pkr, from_usd: usd }, cc, {}); if (q && q.display) return { display: q.display, amount: q.amount, currency: q.currency, symbol: q.symbol, usd: q.usd }; } catch (e) {}
      }
      // fallback: PKR for PK else USD
      if (cc === 'PK') return { display: 'Rs ' + Number(pkr || 0).toLocaleString('en-US'), amount: pkr, currency: 'PKR', symbol: 'Rs ', usd };
      return { display: '$' + (usd || 0), amount: usd, currency: 'USD', symbol: '$', usd };
    },
    rules: async () => [],
    siblings: async () => [],
    relatedCategories: async () => []
  };
}

async function seedPage(ctx, deps) {
  const content = await geoContent.assemble(ctx, deps);
  const quality = gates.qualityScore(content.gateInput);
  const sh = gates.simhash(content.text || '');
  // seed is published NOINDEX for review regardless of score; record the scores
  const contentData = {
    h1: content.h1, intro: content.intro, faq: content.faq,
    internalLinks: content.internalLinks, uniqueTokens: content.uniqueTokens,
    products: content.metaProducts, locale: content.locale, assembledAt: new Date().toISOString()
  };
  const r = await pool.query(
    `INSERT INTO geo_pages
       (page_type,category_id,country_id,region_id,city_id,slug,title,status,indexing_status,
        seo_title,seo_description,canonical_url,content_data,quality_score,updated_at,published_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,'PUBLISHED','NOINDEX',$8,$9,$10,$11,$12,now(),now())
     ON CONFLICT (slug) DO UPDATE SET
       content_data=EXCLUDED.content_data, title=EXCLUDED.title, quality_score=EXCLUDED.quality_score,
       status='PUBLISHED', indexing_status='NOINDEX', updated_at=now()
     RETURNING id,slug`,
    [ctx.page_type, ctx.categoryId, ctx.countryId || null, ctx.regionId || null, ctx.cityId || null,
     ctx.path, content.h1, content.h1, (content.intro[0] || '').slice(0, 158),
     SITE_URL + ctx.path, JSON.stringify(contentData), quality]);
  return { id: r.rows[0].id, slug: r.rows[0].slug, quality };
}

(async () => {
  try {
    console.log('== geo seed: upserting demo locations ==');
    const pk = await upsertLocation({ type: 'country', name: 'Pakistan', slug: 'pakistan', country_code: 'PK', currency: 'PKR', currency_symbol: 'Rs ', demonym: 'Pakistani', languages: ['en', 'ur'], priority: 1 });
    const pesh = await upsertLocation({ type: 'city', name: 'Peshawar', slug: 'peshawar', country_code: 'PK', parent_id: pk.id, demonym: 'Peshawari', languages: ['en', 'ur', 'ps'], priority: 10 });
    console.log('   Pakistan id=' + pk.id + ', Peshawar id=' + pesh.id);

    const catRow = (await pool.query("SELECT id,name,slug FROM categories WHERE lower(slug)='iptv' LIMIT 1")).rows[0]
      || (await pool.query("SELECT id,name,slug FROM categories WHERE active ORDER BY id LIMIT 1")).rows[0];
    if (!catRow) { console.log('No category found — cannot seed. (Need at least one category.)'); process.exit(0); }
    console.log('   using category: ' + catRow.name + ' (#' + catRow.id + ')');
    const settings = await storefront.loadSettings(pool).catch(() => ({}));
    const siteName = settings.site_name || 'Galaxy Subz × Zayron';
    const deps = depsFor(catRow.id);

    const targets = [
      { path: '/' + catRow.slug + '/pakistan', page_type: 'COUNTRY_LANDING', siteName, categoryId: catRow.id, categoryName: catRow.name, categorySlug: catRow.slug,
        countryId: pk.id, country: pk, chain: [pk], target: pk,
        intent: { key: 'BEST', name: 'Best', slug: null } },
      { path: '/' + catRow.slug + '/pakistan/peshawar', page_type: 'CITY_LANDING', siteName, categoryId: catRow.id, categoryName: catRow.name, categorySlug: catRow.slug,
        countryId: pk.id, cityId: pesh.id, country: pk, city: pesh, chain: [pesh, pk], target: pesh,
        intent: { key: 'PRICE', name: 'Pricing', slug: 'pricing' } }
    ];

    const done = [];
    for (const t of targets) {
      try { const res = await seedPage(t, deps); console.log('   seeded ' + res.slug + ' (quality ' + res.quality + ', NOINDEX)'); done.push(res.slug); }
      catch (e) { console.log('   FAILED ' + t.path + ': ' + (e && e.message)); }
    }

    console.log('\n== done ==');
    done.forEach(s => console.log('   view: ' + SITE_URL + s));
    console.log('\nThese are PUBLISHED + NOINDEX (you can see them; Google is told to ignore them).');
    console.log("To hide again:  UPDATE geo_pages SET status='ARCHIVED' WHERE slug IN (" + done.map(s => "'" + s + "'").join(',') + ");");
    await pool.end();
  } catch (e) {
    console.error('seed error:', e && e.message);
    try { await pool.end(); } catch (x) {}
    process.exit(1);
  }
})();
