'use strict';
/* scripts/geo_locations_load.js — load data/geo_locations.json into geo_locations.
 *
 * Idempotent upsert (ON CONFLICT type,slug). Inserts countries, then their
 * regions (parent=country), then cities (parent=region when given, else country).
 * Purely additive — it never deletes or disables anything. Safe to re-run.
 *
 * Run:  node scripts/geo_locations_load.js            (from /opt/gsz after copy)
 *       node scripts/geo_locations_load.js /path/to/geo_locations.json
 */
const path = require('path');
const fs = require('fs');
const GSZ = process.env.GSZ_DIR || '/opt/gsz';
try { require(path.join(GSZ, 'node_modules', 'dotenv')).config({ path: path.join(GSZ, '.env') }); } catch (e) {}
const { Pool } = require(path.join(GSZ, 'node_modules', 'pg'));

const DATA = process.argv[2] || path.join(GSZ, 'data', 'geo_locations.json');
const pool = new Pool({
  host: process.env.DB_HOST, port: Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS
});

async function upsert(loc) {
  const r = await pool.query(
    `INSERT INTO geo_locations(type,name,slug,country_code,parent_id,currency,currency_symbol,demonym,languages,population,enabled,seo_enabled,indexable,priority)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,TRUE,TRUE,TRUE,$11)
     ON CONFLICT (type,slug) DO UPDATE SET
       name=EXCLUDED.name,
       country_code=COALESCE(EXCLUDED.country_code,geo_locations.country_code),
       parent_id=COALESCE(EXCLUDED.parent_id,geo_locations.parent_id),
       currency=COALESCE(EXCLUDED.currency,geo_locations.currency),
       currency_symbol=COALESCE(EXCLUDED.currency_symbol,geo_locations.currency_symbol),
       demonym=COALESCE(EXCLUDED.demonym,geo_locations.demonym),
       languages=EXCLUDED.languages,
       population=COALESCE(EXCLUDED.population,geo_locations.population),
       priority=EXCLUDED.priority, updated_at=now()
     RETURNING id`,
    [loc.type, loc.name, loc.slug, loc.country_code || null, loc.parent_id || null,
     loc.currency || null, loc.currency_symbol || null, loc.demonym || null,
     JSON.stringify(loc.languages || []), loc.population || null, loc.priority || 100]);
  return r.rows[0].id;
}

(async () => {
  try {
    const doc = JSON.parse(fs.readFileSync(DATA, 'utf8'));
    const countries = doc.countries || [];
    let nCountry = 0, nRegion = 0, nCity = 0;
    for (const c of countries) {
      const countryId = await upsert({ type: 'country', name: c.name, slug: c.slug, country_code: c.code, currency: c.currency, currency_symbol: c.symbol, demonym: c.demonym, languages: c.languages, population: c.population, priority: c.priority || 10 });
      nCountry++;
      const regionIds = {};
      for (const r of (c.regions || [])) {
        const id = await upsert({ type: 'region', name: r.name, slug: r.slug, country_code: c.code, parent_id: countryId, currency: c.currency, demonym: r.demonym, languages: r.languages || c.languages, priority: r.priority || 20 });
        regionIds[r.slug] = id; nRegion++;
      }
      for (const ci of (c.cities || [])) {
        const parent = ci.region && regionIds[ci.region] ? regionIds[ci.region] : countryId;
        await upsert({ type: 'city', name: ci.name, slug: ci.slug, country_code: c.code, parent_id: parent, currency: c.currency, currency_symbol: c.symbol, demonym: ci.demonym, languages: ci.languages || c.languages, population: ci.population, priority: ci.priority || 30 });
        nCity++;
      }
      console.log('   ' + c.name + ': ' + (c.regions ? c.regions.length : 0) + ' regions, ' + (c.cities ? c.cities.length : 0) + ' cities');
    }
    const total = (await pool.query('SELECT type, count(*)::int n FROM geo_locations GROUP BY type ORDER BY type')).rows;
    console.log('\n== loaded ==');
    console.log('   this run: ' + nCountry + ' countries, ' + nRegion + ' regions, ' + nCity + ' cities');
    console.log('   geo_locations now holds: ' + total.map(t => t.n + ' ' + t.type).join(', '));
    await pool.end();
  } catch (e) {
    console.error('load error:', e && e.message);
    try { await pool.end(); } catch (x) {}
    process.exit(1);
  }
})();
