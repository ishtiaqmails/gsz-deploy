'use strict';
/* scripts/geo_pick.js — generate "pick" pages: location pages that show ONLY a chosen set of
 * products (a geo_picks row), reusing the normal content engine + quality gate.
 *
 *   node scripts/geo_pick.js <pickId> <scope> <publish>
 *     scope:  c:<countryId>          country page only
 *             c:<countryId>:cities   country + all its cities
 *             all                    every country
 *             all:cities             every country + all cities
 *     publish: "1" = run the gate and publish live; anything else = leave as DRAFT
 *
 * Page shape: page_type='PICK_LANDING', content_data.pick = {id,name,slug,product_ids}.
 * Slug: /<catSlug>/<pickSlug>/<countrySlug>[/<citySlug>] — never collides with the base
 * category/city pages (pickSlug sits where the country slug sits on a base page).
 */
const path = require('path');
const GSZ = process.env.GSZ_DIR || '/opt/gsz';
try { require(path.join(GSZ, 'node_modules', 'dotenv')).config({ path: path.join(GSZ, '.env') }); } catch (e) {}
const { Pool } = require(path.join(GSZ, 'node_modules', 'pg'));
const storefront = require(path.join(GSZ, 'lib', 'storefront'));
const geoAdmin = require(path.join(GSZ, 'lib', 'geo_admin'));
const geoContent = require(path.join(GSZ, 'lib', 'geo_content'));
const geoPublish = require(path.join(GSZ, 'lib', 'geo_publish'));
const pool = new Pool({ host: process.env.DB_HOST, port: Number(process.env.DB_PORT) || 5432, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

function esc(s) { return String(s == null ? '' : s); }

(async () => {
  const pickId = parseInt(process.argv[2], 10);
  const scope = String(process.argv[3] || '');
  const publishLive = String(process.argv[4] || '') === '1';
  if (!pickId || !scope) { console.error('usage: geo_pick.js <pickId> <scope> <publish>'); process.exit(1); }

  const pick = (await pool.query('SELECT * FROM geo_picks WHERE id=$1', [pickId])).rows[0];
  if (!pick) { console.error('pick not found'); process.exit(1); }
  const productIds = (pick.product_ids || []).map(Number).filter(Boolean);
  if (!productIds.length) { console.error('pick has no products'); process.exit(1); }

  const settings = await storefront.loadSettings(pool).catch(() => ({}));
  const siteName = settings.site_name || 'Galaxy Subz × Zayron';
  const cat = (await pool.query('SELECT id,slug,name FROM categories WHERE id=$1', [pick.category_id]).catch(() => ({ rows: [] }))).rows[0]
            || { id: pick.category_id, slug: 'iptv', name: 'IPTV services' };

  // product catalog filtered to the pick (supports products from any category), kept in pick order
  const allRows = await storefront.loadProducts(pool, null).catch(() => []);
  const pmap = {}; allRows.forEach(p => { pmap[p.id] = { id: p.id, name: p.name, slug: p.slug, description: p.descr, price: p.from, usd: p.from_usd, plans: p.plans, available: true }; });
  const pickProducts = productIds.map(id => pmap[id]).filter(Boolean);
  if (!pickProducts.length) { console.error('none of the pick products are live'); process.exit(1); }
  const names = pickProducts.map(p => p.name);

  const baseDeps = geoAdmin.contentDeps(pool, pick.category_id);
  const deps = Object.assign({}, baseDeps, { catalog: async () => pickProducts.slice() });

  // resolve target locations: [{country, city|null}]
  const targets = [];
  async function citiesOf(cc) { return (await pool.query("SELECT * FROM geo_locations WHERE type='city' AND country_code=$1 AND enabled AND seo_enabled ORDER BY name", [cc])).rows; }
  if (scope.indexOf('c:') === 0) {
    const parts = scope.split(':'); const cid = parseInt(parts[1], 10); const withCities = parts[2] === 'cities';
    const country = (await pool.query("SELECT * FROM geo_locations WHERE id=$1 AND type='country'", [cid])).rows[0];
    if (!country) { console.error('country not found'); process.exit(1); }
    targets.push({ country, city: null });
    if (withCities) { for (const ci of await citiesOf(country.country_code)) targets.push({ country, city: ci }); }
  } else if (scope.indexOf('all') === 0) {
    const withCities = scope.indexOf(':cities') >= 0;
    const countries = (await pool.query("SELECT * FROM geo_locations WHERE type='country' AND enabled AND seo_enabled ORDER BY name")).rows;
    for (const country of countries) {
      targets.push({ country, city: null });
      if (withCities) { for (const ci of await citiesOf(country.country_code)) targets.push({ country, city: ci }); }
    }
  } else { console.error('bad scope'); process.exit(1); }

  const existing = new Set((await pool.query('SELECT slug FROM geo_pages')).rows.map(r => r.slug));
  console.log('pick "' + pick.name + '": ' + pickProducts.length + ' products -> ' + targets.length + ' location pages');

  let made = 0, skipped = 0, published = 0;
  for (const t of targets) {
    const loc = t.city || t.country;
    const slug = '/' + cat.slug + '/' + pick.slug + '/' + t.country.slug + (t.city ? ('/' + t.city.slug) : '');
    if (existing.has(slug)) { skipped++; continue; }

    const cand = {
      slug, category_name: cat.name, category_slug: cat.slug, category_id: cat.id,
      country_id: t.country.id, region_id: null, city_id: t.city ? t.city.id : null,
      page_type: 'PICK_LANDING', intent_key: 'BEST', intent_slug: null
    };
    const byId = {}; byId[t.country.id] = t.country; if (t.city) byId[t.city.id] = t.city;
    const ctx = geoAdmin.buildCtx(cand, byId, siteName);

    let content;
    try { content = await geoContent.assemble(ctx, deps); } catch (e) { console.error('assemble failed @ ' + slug + ': ' + e.message); continue; }

    // override with pick-specific, factual copy (keeps engine faq/tokens for local uniqueness)
    const locName = loc.name;
    const cur = t.country.currency || (content.locale && content.locale.currency) || 'USD';
    content.h1 = pick.name + ' in ' + locName;
    const introLine = (pick.intro && pick.intro.trim())
      ? pick.intro.trim()
      : (pick.name + ' for ' + locName + ': ' + names.join(', ') + '. Prices shown in ' + cur + '.');
    content.intro = [introLine];
    content.text = [content.h1, introLine, (content.faq || []).map(f => f.q + ' ' + f.a).join(' '), names.join(' ')].join(' ');
    if (content.gateInput) { content.gateInput.text = content.text; content.gateInput.intro = introLine; content.gateInput.products = content.products; }
    content.pick = { id: pick.id, name: pick.name, slug: pick.slug, product_ids: productIds };

    const title = pick.name + ' in ' + locName;
    const seoTitle = title + ' | ' + siteName;
    const seoDesc = introLine.slice(0, 158);

    let pageId;
    try {
      pageId = (await pool.query(
        "INSERT INTO geo_pages (page_type, category_id, country_id, region_id, city_id, language, title, slug, status, indexing_status, content_data, seo_title, seo_description, created_at, updated_at) " +
        "VALUES ('PICK_LANDING',$1,$2,NULL,$3,'en',$4,$5,'DRAFT','AUTO',$6::jsonb,$7,$8,now(),now()) RETURNING id",
        [cat.id, t.country.id, t.city ? t.city.id : null, title, slug, JSON.stringify(content), seoTitle, seoDesc])).rows[0].id;
    } catch (e) { console.error('insert failed @ ' + slug + ': ' + e.message); continue; }
    existing.add(slug); made++;

    if (publishLive) { try { const r = await geoPublish.publish(pool, pageId); if (r && r.ok) published++; } catch (e) {} }
    if (made % 100 === 0) console.log('   ...' + made + ' pages');
  }

  console.log('done: ' + made + ' created, ' + skipped + ' already existed' + (publishLive ? (', ' + published + ' published') : ' (left as drafts)'));
  await pool.end();
})().catch(async e => { console.error('error:', e && e.message); try { await pool.end(); } catch (x) {} process.exit(1); });
