'use strict';
/* lib/geo_bulk.js — bulk geo-page planning, opportunity scoring, and DRAFT staging.
 *
 * Expands (location x category x intent) into candidate pages, scores each for
 * opportunity, and stages them in geo_pages as DRAFT — it NEVER publishes. A
 * human (or a later gated auto-publish) promotes DRAFT -> PUBLISHED. The public
 * route only ever serves an exact PUBLISHED slug, so nothing here can affect the
 * live site until a page is explicitly published.
 *
 * Slug model (canonical, unique in geo_pages.slug):
 *   /{cat}/{country}
 *   /{cat}/{country}/{intent}
 *   /{cat}/{country}/{city}
 *   /{cat}/{country}/{city}/{intent}
 *
 * Pure:
 *   slugFor(parts)             -> '/iptv/pakistan/peshawar/pricing'
 *   opportunityScore(combo)    -> 0..100
 *   planMatrix(inputs, opts)   -> [ candidate, ... ]  (capped, deduped vs existing)
 * DB:
 *   stage(pool, candidates, deps, opts) -> { created, skipped, drafts:[] }
 */
const gates = require('./seo_gates');

const INTENT_WEIGHT = {
  BUY: 100, PRICE: 95, BEST: 90, TRIAL: 85, CHANNELS: 70, SPORTS: 70,
  COMPARE: 65, REVIEW: 55, HOW_TO: 50, LOCAL: 60, AVAILABILITY: 45,
  DEVICE: 40, PROBLEM_SOLUTION: 40
};
const TYPE_WEIGHT = { country: 1.0, region: 0.8, city: 0.9, area: 0.6, global: 0.5 };

function slugify(s) {
  return String(s || '').toLowerCase().trim()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}
// parts: { category, country, region?, city?, intentSlug? }
function slugFor(p) {
  const seg = ['', slugify(p.category), slugify(p.country)];
  if (p.city) seg.push(slugify(p.city));
  else if (p.region) seg.push(slugify(p.region));
  if (p.intentSlug) seg.push(slugify(p.intentSlug));
  return seg.join('/').replace(/\/{2,}/g, '/');
}

function pageTypeFor(combo) {
  if (combo.city) return combo.intent && combo.intent.slug ? 'CITY_INTENT' : 'CITY_LANDING';
  if (combo.region) return combo.intent && combo.intent.slug ? 'REGION_INTENT' : 'REGION_LANDING';
  return combo.intent && combo.intent.slug ? 'COUNTRY_INTENT' : 'COUNTRY_LANDING';
}

// combo: { location:{type,priority,population,seo_enabled}, category:{demand?}, intent:{key} }
function opportunityScore(combo) {
  const loc = combo.location || {};
  const intent = combo.intent || {};
  const cat = combo.category || {};
  const tw = TYPE_WEIGHT[loc.type] != null ? TYPE_WEIGHT[loc.type] : 0.7;
  const iw = (INTENT_WEIGHT[intent.key] != null ? INTENT_WEIGHT[intent.key] : 50) / 100;
  // population -> 0..1 (log-ish; 5M+ ~= full)
  const pop = loc.population ? Math.min(1, Math.log10(loc.population + 10) / Math.log10(5000000)) : 0.4;
  // priority: lower number = more important (default 100). Map 1..200 -> 1..0.
  const pr = loc.priority != null ? Math.max(0, Math.min(1, 1 - (loc.priority / 200))) : 0.5;
  const demand = cat.demand != null ? Math.max(0, Math.min(1, cat.demand)) : 0.6;
  const raw = (tw * 0.2) + (iw * 0.3) + (pop * 0.2) + (pr * 0.15) + (demand * 0.15);
  return Math.round(raw * 100);
}

/* inputs: { categories:[{id,slug,name,demand?}], locations:[{...geo_locations row}],
 *          intents:[{id,key,name,slug}], existingSlugs:Set|[] }
 * opts: { limit=500, minOpportunity=0, includeBaseIntent=true, countriesOnlyFor=[] } */
function planMatrix(inputs, opts) {
  inputs = inputs || {}; opts = Object.assign({ limit: 500, minOpportunity: 0 }, opts || {});
  const cats = inputs.categories || [];
  const locs = (inputs.locations || []).filter(l => l && l.seo_enabled !== false && l.enabled !== false);
  const intents = (inputs.intents || []).slice();
  const existing = inputs.existingSlugs instanceof Set ? inputs.existingSlugs
    : new Set(inputs.existingSlugs || []);

  // Ensure a base (no-intent) landing is considered.
  const intentList = intents.slice();
  if (opts.includeBaseIntent !== false && !intentList.some(i => !i.slug)) intentList.unshift({ key: 'BEST', name: 'Best', slug: null });

  const out = [];
  for (const cat of cats) {
    for (const loc of locs) {
      // find country/region/city context from the loc row + its denormalized names
      const ctx = locContext(loc, inputs.byId || {});
      for (const intent of intentList) {
        const combo = { location: loc, category: cat, intent };
        const parts = {
          category: cat.slug,
          country: ctx.countryName, region: ctx.regionName, city: ctx.cityName,
          intentSlug: intent.slug || null
        };
        if (!parts.country) continue;                 // every geo page hangs off a country
        const slug = slugFor(parts);
        if (existing.has(slug)) continue;
        const score = opportunityScore(combo);
        if (score < opts.minOpportunity) continue;
        out.push({
          slug, opportunityScore: score,
          page_type: pageTypeFor({ city: ctx.cityId ? loc : null, region: ctx.regionId && !ctx.cityId ? loc : null, intent }),
          category_id: cat.id, category_slug: cat.slug, category_name: cat.name,
          country_id: ctx.countryId, region_id: ctx.regionId, city_id: ctx.cityId,
          intent_id: intent.id || null, intent_key: intent.key, intent_slug: intent.slug || null,
          location_id: loc.id, location_name: loc.name, location_type: loc.type
        });
      }
    }
  }
  out.sort((a, b) => b.opportunityScore - a.opportunityScore);
  return out.slice(0, opts.limit);
}

// Derive country/region/city ids+names for a location row using a byId map of ancestors.
function locContext(loc, byId) {
  const chain = []; let cur = loc, guard = 0;
  while (cur && guard++ < 8) { chain.push(cur); if (!cur.parent_id) break; cur = byId[cur.parent_id]; }
  const find = t => chain.find(r => r.type === t) || null;
  const country = find('country'), region = find('region'), city = find('city') || (loc.type === 'city' ? loc : null);
  return {
    countryId: country ? country.id : (loc.type === 'country' ? loc.id : null),
    countryName: country ? country.name : (loc.type === 'country' ? loc.name : null),
    regionId: region ? region.id : null, regionName: region ? region.name : null,
    cityId: city ? city.id : null, cityName: city ? city.name : null
  };
}

/* stage: assemble content for each candidate, gate it, INSERT as DRAFT.
 * deps: { assembleFor(candidate) -> contentModel, existingSimhashes:[] (optional) }
 * Returns { created, skipped, drafts:[{slug,quality,duplicate,indexingRec}] } */
async function stage(pool, candidates, deps, opts) {
  deps = deps || {}; opts = opts || {};
  const existingSim = (deps.existingSimhashes || []).slice();
  let created = 0, skipped = 0; const drafts = [];
  for (const c of candidates) {
    // skip if slug already exists (race-safe)
    const dup = await pool.query('SELECT 1 FROM geo_pages WHERE slug=$1 LIMIT 1', [c.slug]);
    if (dup.rows.length) { skipped++; continue; }

    let content = null, quality = null, duplicate = 0, sh = null, indexingRec = 'AUTO';
    if (typeof deps.assembleFor === 'function') {
      content = await deps.assembleFor(c);
      if (content && content.gateInput) {
        quality = gates.qualityScore(content.gateInput);
        sh = gates.simhash(content.text || '');
        duplicate = gates.duplicateScore(sh, existingSim);
        const decision = gates.decideIndexing({ status: 'DRAFT', page: content.gateInput, simhash: sh, existing: existingSim });
        // store the recommendation the gate WOULD make once published
        const pub = gates.decideIndexing({ status: 'PUBLISHED', quality, duplicate, simhash: sh, existing: existingSim });
        indexingRec = pub.indexing;
        if (sh) existingSim.push(sh);
      }
    }
    const title = content ? content.h1 : null;
    const contentData = content ? {
      h1: content.h1, intro: content.intro, faq: content.faq,
      internalLinks: content.internalLinks, uniqueTokens: content.uniqueTokens,
      products: content.metaProducts, locale: content.locale, assembledAt: new Date().toISOString()
    } : {};

    const r = await pool.query(
      `INSERT INTO geo_pages
        (page_type,category_id,country_id,region_id,city_id,intent_id,slug,title,status,indexing_status,
         content_data,quality_score,duplicate_score,opportunity_score,updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'DRAFT','AUTO',$9,$10,$11,$12,now())
       ON CONFLICT (slug) DO NOTHING
       RETURNING id`,
      [c.page_type, c.category_id, c.country_id, c.region_id, c.city_id, c.intent_id, c.slug, title,
       JSON.stringify(contentData), quality, duplicate, c.opportunityScore]);
    if (r.rows.length) { created++; drafts.push({ id: r.rows[0].id, slug: c.slug, quality, duplicate, indexingRec, opportunity: c.opportunityScore }); }
    else skipped++;
  }
  return { created, skipped, drafts };
}

module.exports = { slugFor, slugify, opportunityScore, planMatrix, stage, pageTypeFor, locContext, INTENT_WEIGHT };
