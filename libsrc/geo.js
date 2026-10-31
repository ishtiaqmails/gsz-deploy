'use strict';
/* lib/geo.js — geo resolution service for the Geo Page Engine.
 *
 * Responsibilities (pure resolution + inheritance; no rendering, no routes):
 *   - resolve a URL location path (/country[/region][/city]) to geo_locations rows
 *   - build the ancestry chain (city -> region -> country) for inheritance
 *   - value-level fallback: cityValue ?? regionValue ?? countryValue ?? globalValue
 *   - product/location rules merged along the chain (city overrides region overrides country)
 *   - thin reuse hooks for the live currency engine (gsz_pricing) and catalog (storefront)
 *
 * In-process cache (5 min) keeps /iptv/pakistan/peshawar resolution off the hot path.
 * Everything is read-only against additive tables; safe to require even before pages exist.
 */
module.exports = function (pool) {
  const CACHE_TTL = 5 * 60 * 1000;
  const _cache = {};
  const cget = k => { const e = _cache[k]; return (e && Date.now() - e.at < CACHE_TTL) ? e.v : undefined; };
  const cput = (k, v) => { _cache[k] = { v, at: Date.now() }; return v; };
  const cclear = () => { for (const k in _cache) delete _cache[k]; };

  async function locBySlug(type, slug) {
    const k = 'loc:' + type + ':' + slug; const c = cget(k); if (c !== undefined) return c;
    const r = (await pool.query(
      'SELECT * FROM geo_locations WHERE type=$1 AND lower(slug)=lower($2) AND enabled LIMIT 1',
      [type, slug])).rows[0] || null;
    return cput(k, r);
  }
  async function childBySlug(parentId, type, slug) {
    const k = 'child:' + parentId + ':' + type + ':' + slug; const c = cget(k); if (c !== undefined) return c;
    const r = (await pool.query(
      'SELECT * FROM geo_locations WHERE parent_id=$1 AND type=$2 AND lower(slug)=lower($3) AND enabled LIMIT 1',
      [parentId, type, slug])).rows[0] || null;
    return cput(k, r);
  }
  async function byId(id) {
    if (!id) return null;
    const k = 'id:' + id; const c = cget(k); if (c !== undefined) return c;
    const r = (await pool.query('SELECT * FROM geo_locations WHERE id=$1', [id])).rows[0] || null;
    return cput(k, r);
  }

  // A city/region by slug anywhere within a country (via denormalized country_code OR direct parent),
  // so /pakistan/peshawar resolves even when Peshawar belongs to a region internally.
  async function inCountry(type, slug, countryCode, countryId) {
    const k = 'inc:' + type + ':' + slug + ':' + countryCode + ':' + countryId; const c = cget(k); if (c !== undefined) return c;
    const r = (await pool.query(
      'SELECT * FROM geo_locations WHERE type=$1 AND lower(slug)=lower($2) AND enabled AND (country_code=$3 OR parent_id=$4) LIMIT 1',
      [type, slug, countryCode, countryId])).rows[0] || null;
    return cput(k, r);
  }

  // Resolve ['pakistan'] | ['pakistan','peshawar'] | ['pakistan','kpk','peshawar'] -> {country,region,city,target}
  async function resolvePath(parts) {
    parts = (parts || []).filter(Boolean).map(s => String(s).toLowerCase());
    if (!parts.length) return null;
    const country = await locBySlug('country', parts[0]);
    if (!country) return null;
    const cc = country.country_code || country.iso_code || null;
    let region = null, city = null;
    if (parts[1]) {
      city = await inCountry('city', parts[1], cc, country.id);
      if (!city) {
        region = await inCountry('region', parts[1], cc, country.id);
        if (region && parts[2]) city = await childBySlug(region.id, 'city', parts[2]);
      }
    }
    return { country, region, city, target: city || region || country };
  }

  // Ancestry chain from a target up to its country: [city?, region?, country] (nulls removed)
  async function chain(target) {
    const out = []; let cur = target; let guard = 0;
    while (cur && guard++ < 8) { out.push(cur); if (!cur.parent_id) break; cur = await byId(cur.parent_id); }
    return out;
  }

  // Value-level inheritance/fallback: first non-empty value walking the chain (city->...->country),
  // then an optional global default. Reads either a column or metadata.<key>.
  function inheritValue(chainRows, field, globalDefault) {
    for (const r of chainRows) {
      if (!r) continue;
      if (r[field] != null && r[field] !== '') return r[field];
      if (r.metadata && r.metadata[field] != null && r.metadata[field] !== '') return r.metadata[field];
    }
    return (globalDefault === undefined ? null : globalDefault);
  }

  // Product/location recommendation rules for a target, merged along the ancestry chain so a
  // city-level rule for a product overrides the country-level one. Optional category filter.
  async function recommendedRules(target, opts) {
    opts = opts || {};
    const rows = await chain(target);
    const ids = rows.map(r => r.id);
    if (!ids.length) return [];
    const params = [ids];
    let where = 'location_id = ANY($1) AND enabled';
    if (opts.categoryId) { params.push(opts.categoryId); where += ' AND (category_id=$' + params.length + ' OR category_id IS NULL)'; }
    const rules = (await pool.query(
      'SELECT * FROM geo_product_rules WHERE ' + where, params)).rows;
    // depth weight: city(0) most specific. Keep the most specific rule per product_id.
    const depth = {}; ids.forEach((id, i) => { depth[id] = i; });
    const best = {};
    for (const r of rules) {
      const key = (r.product_id != null ? 'p' + r.product_id : 'c' + r.category_id);
      const d = depth[r.location_id] == null ? 99 : depth[r.location_id];
      if (!best[key] || d < best[key]._depth) { r._depth = d; best[key] = r; }
    }
    return Object.values(best).sort((a, b) =>
      (b.priority - a.priority) || (Number(b.recommendation_score) - Number(a.recommendation_score)));
  }

  const pricing = () => { try { return require('./gsz_pricing'); } catch (e) { return null; } };

  return {
    resolvePath, chain, inheritValue, recommendedRules,
    locBySlug, childBySlug, byId, pricing, cclear, _cache
  };
};
