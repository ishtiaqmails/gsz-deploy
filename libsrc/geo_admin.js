'use strict';
/* lib/geo_admin.js — shared engine operations for the Geo Page Engine.
 *
 * One source of truth used by BOTH the admin routes and the CLI scripts, so
 * there's no duplicated catalog/price/assemble logic lying around:
 *   contentDeps(pool, categoryId)    -> DI deps for geo_content.assemble
 *   buildCtx(cand, byId, siteName)   -> assemble ctx from a bulk candidate
 *   loadLocations(pool, dataPath)    -> upsert data/geo_locations.json
 *   generate(pool, opts)             -> plan + stage DRAFT pages (nothing published)
 *   locationsSummary(pool)           -> counts by type
 *   pagesSummary(pool)               -> counts by status + indexing
 *
 * Nothing here publishes or pings — see lib/geo_publish.js for that.
 */
const path = require('path');
const fs = require('fs');

function lib(name) { try { return require(path.join(__dirname, name)); } catch (e) { return null; } }
const geoContent = lib('geo_content');
const geoBulk = lib('geo_bulk');
const storefront = lib('storefront');
const pricing = lib('gsz_pricing');

function contentDeps(pool, categoryId) {
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

function buildCtx(cand, byId, siteName) {
  const country = byId[cand.country_id] || null, region = byId[cand.region_id] || null, city = byId[cand.city_id] || null;
  const target = city || region || country;
  const chain = [city, region, country].filter(Boolean);
  return {
    path: cand.slug, siteName: siteName || 'Galaxy Subz × Zayron',
    categoryName: cand.category_name, categorySlug: cand.category_slug, categoryId: cand.category_id,
    countryId: cand.country_id, regionId: cand.region_id, cityId: cand.city_id,
    country, region, city, chain, target,
    page_type: cand.page_type, intent: { key: cand.intent_key || 'BEST', slug: cand.intent_slug || null }
  };
}

async function upsertLocation(pool, loc) {
  const r = await pool.query(
    `INSERT INTO geo_locations(type,name,slug,country_code,parent_id,currency,currency_symbol,demonym,languages,population,enabled,seo_enabled,indexable,priority)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,TRUE,TRUE,TRUE,$11)
     ON CONFLICT (type,slug) DO UPDATE SET
       name=EXCLUDED.name, country_code=COALESCE(EXCLUDED.country_code,geo_locations.country_code),
       parent_id=COALESCE(EXCLUDED.parent_id,geo_locations.parent_id),
       currency=COALESCE(EXCLUDED.currency,geo_locations.currency),
       currency_symbol=COALESCE(EXCLUDED.currency_symbol,geo_locations.currency_symbol),
       demonym=COALESCE(EXCLUDED.demonym,geo_locations.demonym),
       languages=EXCLUDED.languages, population=COALESCE(EXCLUDED.population,geo_locations.population),
       priority=EXCLUDED.priority, updated_at=now()
     RETURNING id`,
    [loc.type, loc.name, loc.slug, loc.country_code || null, loc.parent_id || null,
     loc.currency || null, loc.currency_symbol || null, loc.demonym || null,
     JSON.stringify(loc.languages || []), loc.population || null, loc.priority || 100]);
  return r.rows[0].id;
}

async function loadLocations(pool, dataPath) {
  const doc = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  let nCountry = 0, nRegion = 0, nCity = 0;
  for (const c of (doc.countries || [])) {
    const countryId = await upsertLocation(pool, { type: 'country', name: c.name, slug: c.slug, country_code: c.code, currency: c.currency, currency_symbol: c.symbol, demonym: c.demonym, languages: c.languages, population: c.population, priority: c.priority || 10 });
    nCountry++;
    const regionIds = {};
    for (const r of (c.regions || [])) { regionIds[r.slug] = await upsertLocation(pool, { type: 'region', name: r.name, slug: r.slug, country_code: c.code, parent_id: countryId, currency: c.currency, demonym: r.demonym, languages: r.languages || c.languages, priority: r.priority || 20 }); nRegion++; }
    for (const ci of (c.cities || [])) { const parent = ci.region && regionIds[ci.region] ? regionIds[ci.region] : countryId; await upsertLocation(pool, { type: 'city', name: ci.name, slug: ci.slug, country_code: c.code, parent_id: parent, currency: c.currency, currency_symbol: c.symbol, demonym: ci.demonym, languages: ci.languages || c.languages, population: ci.population, priority: ci.priority || 30 }); nCity++; }
  }
  return { countries: nCountry, regions: nRegion, cities: nCity };
}

// generate(pool, { categorySlugs:['iptv'], limit:1000, siteName }) -> stage DRAFTs
async function generate(pool, opts) {
  opts = opts || {};
  const settings = await storefront.loadSettings(pool).catch(() => ({}));
  const siteName = opts.siteName || settings.site_name || 'Galaxy Subz × Zayron';
  const allCats = await storefront.loadCats(pool).catch(() => []);
  const want = (opts.categorySlugs && opts.categorySlugs.length ? opts.categorySlugs : ['iptv']).map(s => String(s).toLowerCase());
  const cats = allCats.filter(c => want.includes(String(c.slug).toLowerCase()));
  if (!cats.length) return { error: 'no_matching_category', available: allCats.map(c => c.slug) };

  const locs = (await pool.query('SELECT * FROM geo_locations WHERE enabled AND seo_enabled')).rows;
  if (!locs.length) return { error: 'no_locations' };
  const byId = {}; locs.forEach(l => { byId[l.id] = l; });
  const existingSlugs = new Set((await pool.query('SELECT slug FROM geo_pages')).rows.map(r => r.slug));

  const plan = geoBulk.planMatrix(
    { categories: cats.map(c => ({ id: c.id, slug: c.slug, name: c.name, demand: 0.8 })), locations: locs, intents: [{ key: 'BEST', slug: null }], byId, existingSlugs },
    { limit: opts.limit || 1000, includeBaseIntent: true });

  const depsCache = {};
  const assembleFor = async (cand) => {
    const dep = depsCache[cand.category_id] || (depsCache[cand.category_id] = contentDeps(pool, cand.category_id));
    return geoContent.assemble(buildCtx(cand, byId, siteName), dep);
  };
  const res = await geoBulk.stage(pool, plan, { assembleFor });
  const idx = res.drafts.filter(d => d.indexingRec === 'INDEX').length;
  return { planned: plan.length, created: res.created, skipped: res.skipped, wouldIndex: idx, wouldNoindex: res.drafts.length - idx };
}

async function locationsSummary(pool) {
  const rows = (await pool.query('SELECT type, count(*)::int n FROM geo_locations GROUP BY type')).rows;
  const out = { country: 0, region: 0, city: 0, total: 0 };
  rows.forEach(r => { out[r.type] = r.n; out.total += r.n; });
  return out;
}
async function pagesSummary(pool) {
  const rows = (await pool.query("SELECT status, indexing_status, count(*)::int n FROM geo_pages GROUP BY status, indexing_status")).rows;
  const out = { DRAFT: 0, PUBLISHED: 0, ARCHIVED: 0, REVIEW: 0, index: 0, noindex: 0, total: 0 };
  rows.forEach(r => { out[r.status] = (out[r.status] || 0) + r.n; out.total += r.n; if (r.status === 'PUBLISHED') { if (r.indexing_status === 'NOINDEX') out.noindex += r.n; else out.index += r.n; } });
  return out;
}

module.exports = { contentDeps, buildCtx, upsertLocation, loadLocations, generate, locationsSummary, pagesSummary };
