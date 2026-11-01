'use strict';
/* scripts/geo_country.js — type a country, get ALL its cities as live geo SEO pages.
 *
 *   node scripts/geo_country.js "Pakistan"              # all categories, publish live
 *   node scripts/geo_country.js "United Kingdom" iptv    # only the iptv category
 *   node scripts/geo_country.js "Pakistan" all --draft   # stage drafts, don't publish yet
 *   node scripts/geo_country.js "US" iptv,vpn            # a couple of categories
 *
 * Reuses the existing engine (no new page logic):
 *   geo_admin.upsertLocation  -> add the country + every city as locations
 *   geo_admin.generate        -> stage the country page + every city page (per category)
 *   geo_publish.publish       -> take them live (the gate decides index / noindex)
 * Additive + idempotent: safe to re-run, never deletes. Cities come from the offline
 * world dataset (country-state-city) so there is no API limit on how many we create.
 */
const path = require('path');
const GSZ = process.env.GSZ_DIR || '/opt/gsz';
try { require(path.join(GSZ, 'node_modules', 'dotenv')).config({ path: path.join(GSZ, '.env') }); } catch (e) {}
const { Pool } = require(path.join(GSZ, 'node_modules', 'pg'));
const lib = n => require(path.join(GSZ, 'lib', n));
const geoAdmin = lib('geo_admin');
const geoPublish = lib('geo_publish');
const world = lib('geo_world');

const pool = new Pool({
  host: process.env.DB_HOST, port: Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS
});

const argv = process.argv.slice(2);
const draft = argv.indexOf('--draft') >= 0;
const pos = argv.filter(a => a.indexOf('--') !== 0);
const countryName = pos[0];
const catArg = (pos[1] || 'all').toLowerCase();

async function resolveCats() {
  if (catArg !== 'all') { const c = catArg.split(',').map(s => s.trim()).filter(Boolean); return c.length ? c : ['iptv']; }
  // probe generate with a non-existent category to learn the available slugs, then use them all
  try {
    const probe = await geoAdmin.generate(pool, { categorySlugs: ['__none__'], limit: 0 });
    if (probe && Array.isArray(probe.available) && probe.available.length) return probe.available;
  } catch (e) {}
  return ['iptv'];
}

(async () => {
  if (!countryName) { console.error('Usage: node scripts/geo_country.js "<Country>" [category|all] [--draft]'); process.exit(1); }
  if (!world.available()) { console.error('country-state-city is not installed. Run: cd ' + GSZ + ' && npm install country-state-city'); process.exit(1); }

  const c = world.resolveCountry(countryName);
  if (!c) { console.error('Country not found: "' + countryName + '". Try the full name or ISO code (e.g. PK).'); await pool.end(); process.exit(1); }
  console.log('== ' + c.name + ' (' + c.iso + ', ' + (c.currency || '—') + ') ==');

  // 1) country location
  const countryId = await geoAdmin.upsertLocation(pool, { type: 'country', name: c.name, slug: c.slug, country_code: c.iso, currency: c.currency, priority: 10 });

  // 2) every city (collision-safe slugs so a same-named city in another country never clobbers it)
  const cities = world.citiesOf(c.iso);
  console.log('   cities in dataset: ' + cities.length);
  let added = 0;
  for (const ci of cities) {
    let slug = ci.slug;
    const ex = (await pool.query("SELECT country_code FROM geo_locations WHERE type='city' AND lower(slug)=lower($1) LIMIT 1", [slug])).rows[0];
    if (ex && ex.country_code && ex.country_code !== c.iso) slug = ci.slug + '-' + c.iso.toLowerCase();
    await geoAdmin.upsertLocation(pool, { type: 'city', name: ci.name, slug: slug, country_code: c.iso, parent_id: countryId, currency: c.currency, priority: 30 });
    added++;
    if (added % 250 === 0) console.log('   ...' + added + ' cities upserted');
  }
  console.log('   cities upserted: ' + added);

  // 3) stage pages (country + all cities) for each category
  const cats = await resolveCats();
  console.log('   categories: ' + cats.join(', '));
  const g = await geoAdmin.generate(pool, { categorySlugs: cats, limit: 1000000 });
  if (g && g.error) console.log('   generate note: ' + g.error + (g.available ? (' (available: ' + g.available.join(',') + ')') : ''));
  else console.log('   generate: ' + JSON.stringify(g).slice(0, 180));

  // 4) publish them live (unless --draft). Match any DRAFT page tied to this country or its locations.
  if (!draft) {
    const locIds = (await pool.query("SELECT id FROM geo_locations WHERE country_code=$1", [c.iso])).rows.map(r => r.id);
    const ids = (await pool.query(
      "SELECT id FROM geo_pages WHERE status='DRAFT' AND (country_id=$1 OR city_id = ANY($2) OR region_id = ANY($2))",
      [countryId, locIds])).rows.map(r => r.id);
    console.log('   publishing ' + ids.length + ' pages...');
    let ok = 0, idx = 0, noidx = 0, fail = 0;
    for (const id of ids) {
      try { const r = await geoPublish.publish(pool, id); if (r && r.ok) { ok++; if (/noindex/i.test(r.indexing || '')) noidx++; else idx++; } else fail++; }
      catch (e) { fail++; }
      if (ok && ok % 200 === 0) console.log('   ...published ' + ok);
    }
    console.log('   published: ' + ok + ' (' + idx + ' indexable, ' + noidx + ' noindex)' + (fail ? (', ' + fail + ' skipped') : ''));
  } else {
    console.log('   --draft: staged only. Publish from /admin/geo or re-run without --draft.');
  }

  const sum = await geoAdmin.pagesSummary(pool);
  console.log('== done ==  pages now: ' + JSON.stringify(sum));
  await pool.end();
})().catch(async e => { console.error('error:', e && e.message); try { await pool.end(); } catch (x) {} process.exit(1); });
