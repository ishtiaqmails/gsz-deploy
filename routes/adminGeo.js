'use strict';
/* routes/adminGeo.js — admin UI for the Geo Page Engine. Mount at /admin.
 *   GET  /admin/geo                 dashboard: counts + paginated/filtered page list
 *   POST /admin/geo/load-locations  load data/geo_locations.json
 *   POST /admin/geo/country         type a country -> generate all its city pages (background)
 *   POST /admin/geo/generate        stage DRAFT pages (category x locations)
 *   POST /admin/geo/bulk            bulk publish / unpublish / delete (selected or all-matching)
 *   POST /admin/geo/publish         publish one page
 *   POST /admin/geo/unpublish       archive one page
 *   POST /admin/geo/recompute       re-evaluate indexing for all published pages
 * Auth: same guard as the rest of /admin (req.session.admin).
 */
const express = require('express');
const path = require('path');

module.exports = function (pool) {
  const router = express.Router();
  const urlenc = express.urlencoded({ extended: true });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  const lib = (n) => { try { return require(path.join(__dirname, '..', 'lib', n)); } catch (e) { return null; } };
  const geoAdmin = lib('geo_admin');
  const geoPublish = lib('geo_publish');
  const DATA = path.join(__dirname, '..', 'data', 'geo_locations.json');
  function enc(s) { return encodeURIComponent(String(s).slice(0, 180)); }

  // --- filters -> WHERE clause (shared by the list and bulk "all matching") ---
  function filterSql(src) {
    const where = []; const args = [];
    const status = String(src.status || 'ALL').toUpperCase();
    if (['DRAFT', 'PUBLISHED', 'ARCHIVED', 'REVIEW'].indexOf(status) >= 0) { args.push(status); where.push('status=$' + args.length); }
    const idx = String(src.idx || 'ALL').toUpperCase();
    if (idx === 'INDEX') where.push("indexing_status='INDEX'");
    else if (idx === 'NOINDEX') where.push("(indexing_status IS NULL OR indexing_status<>'INDEX')");
    const term = String(src.q || '').trim().toLowerCase();
    if (term) { args.push('%' + term + '%'); where.push('(lower(slug) LIKE $' + args.length + " OR lower(coalesce(title,'')) LIKE $" + args.length + ')'); }
    return { clause: where.length ? (' WHERE ' + where.join(' AND ')) : '', args };
  }

  async function dashData(req) {
    const [locs, pages] = await Promise.all([
      geoAdmin ? geoAdmin.locationsSummary(pool).catch(() => ({})) : {},
      geoAdmin ? geoAdmin.pagesSummary(pool).catch(() => ({})) : {}
    ]);
    const per = Math.min(Math.max(parseInt(req.query.per, 10) || 50, 10), 200);
    let page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const f = filterSql(req.query);
    const total = (await pool.query('SELECT count(*)::int n FROM geo_pages' + f.clause, f.args).catch(() => ({ rows: [{ n: 0 }] }))).rows[0].n || 0;
    const totalPages = Math.max(Math.ceil(total / per), 1);
    if (page > totalPages) page = totalPages;
    const off = (page - 1) * per;
    const rows = (await pool.query(
      "SELECT id,slug,title,status,indexing_status,quality_score,duplicate_score,opportunity_score,page_type FROM geo_pages" + f.clause +
      " ORDER BY (status='PUBLISHED') DESC, opportunity_score DESC NULLS LAST, id DESC LIMIT " + per + " OFFSET " + off, f.args).catch(() => ({ rows: [] }))).rows;
    const cats = (await pool.query("SELECT slug,name FROM categories WHERE active ORDER BY name").catch(() => ({ rows: [] }))).rows;
    const filt = { q: String(req.query.q || ''), status: String(req.query.status || 'ALL').toUpperCase(), idx: String(req.query.idx || 'ALL').toUpperCase() };
    // query string carrying the current filter (for links + bulk "all matching")
    const qs = 'q=' + encodeURIComponent(filt.q) + '&status=' + filt.status + '&idx=' + filt.idx + '&per=' + per;
    return {
      title: 'Geo SEO Pages', active: 'geo', locs, pages, rows, cats,
      flash: req.query.ok || null, err: req.query.err || null,
      siteUrl: (process.env.SITE_URL || 'https://galaxyzayron.store').replace(/\/+$/, ''),
      pg: { page, per, total, totalPages, off, from: total ? off + 1 : 0, to: Math.min(off + per, total) },
      filt, qs
    };
  }

  router.get('/geo', auth, async (req, res) => {
    try { res.render('admin/geo', await dashData(req)); }
    catch (e) { res.status(500).send('geo admin error: ' + e.message); }
  });

  router.post('/geo/load-locations', auth, urlenc, async (req, res) => {
    try { const r = await geoAdmin.loadLocations(pool, DATA); res.redirect('/admin/geo?ok=' + enc('Loaded ' + r.countries + ' countries, ' + r.regions + ' regions, ' + r.cities + ' cities')); }
    catch (e) { res.redirect('/admin/geo?err=' + enc('Load failed: ' + e.message)); }
  });

  router.post('/geo/country', auth, urlenc, async (req, res) => {
    try {
      const country = String(req.body.country || '').trim();
      const cats = (String(req.body.category || 'iptv').trim()) || 'iptv';
      if (!country) return res.redirect('/admin/geo?err=' + enc('Enter a country name'));
      const cp = require('child_process'); const fs = require('fs');
      const GSZ = path.join(__dirname, '..');
      const live = String(req.body.publish || '') === '1';
      const args = [path.join(GSZ, 'scripts', 'geo_country.js'), country, cats]; if (!live) args.push('--draft');
      let out = 'ignore'; try { out = fs.openSync(path.join(GSZ, '.geo_country.log'), 'a'); } catch (e) {}
      const child = cp.spawn(process.execPath, args, { cwd: GSZ, detached: true, stdio: ['ignore', out, out], env: process.env });
      child.unref();
      res.redirect('/admin/geo?ok=' + enc('Started ' + (live ? 'generating + publishing' : 'staging drafts') + ' for all cities of "' + country + '" (' + cats + '). Refresh in a few seconds to watch pages appear.'));
    } catch (e) { res.redirect('/admin/geo?err=' + enc('Country generate failed: ' + e.message)); }
  });

  router.post('/geo/generate', auth, urlenc, async (req, res) => {
    try {
      const cats = String(req.body.categories || 'iptv').split(',').map(s => s.trim()).filter(Boolean);
      const limit = Math.min(parseInt(req.body.limit, 10) || 1000, 5000);
      const r = await geoAdmin.generate(pool, { categorySlugs: cats, limit });
      if (r.error) return res.redirect('/admin/geo?err=' + enc(r.error + (r.available ? (' (have: ' + r.available.join(',') + ')') : '')));
      res.redirect('/admin/geo?ok=' + enc('Staged ' + r.created + ' draft pages (' + r.wouldIndex + ' would index, ' + r.wouldNoindex + ' noindex). Skipped ' + r.skipped + ' existing.'));
    } catch (e) { res.redirect('/admin/geo?err=' + enc('Generate failed: ' + e.message)); }
  });

  // --- bulk: publish / unpublish / delete on selected ids OR everything matching the filter ---
  router.post('/geo/bulk', auth, urlenc, async (req, res) => {
    const retQs = String(req.body.ret || '');
    const back = '/admin/geo' + (retQs ? ('?' + retQs) : '');
    try {
      const action = String(req.body.action || '').toLowerCase();
      let ids;
      if (String(req.body.all || '') === '1') {
        const f = filterSql(req.body);
        ids = (await pool.query('SELECT id FROM geo_pages' + f.clause, f.args)).rows.map(r => r.id);
      } else {
        ids = String(req.body.ids || '').split(',').map(x => parseInt(x, 10)).filter(Boolean);
      }
      if (!ids.length) return res.redirect(back + (back.indexOf('?') >= 0 ? '&' : '?') + 'err=' + enc('No pages selected'));
      const msg = (t) => res.redirect(back + (back.indexOf('?') >= 0 ? '&' : '?') + 'ok=' + enc(t));

      if (action === 'delete') { await pool.query('DELETE FROM geo_pages WHERE id = ANY($1)', [ids]); return msg('Deleted ' + ids.length + ' pages'); }
      if (action === 'unpublish') { await pool.query("UPDATE geo_pages SET status='ARCHIVED', indexing_status='NOINDEX', updated_at=now() WHERE id = ANY($1)", [ids]); return msg('Unpublished ' + ids.length + ' pages'); }
      if (action === 'publish') {
        if (ids.length <= 150) {
          let ok = 0; for (const id of ids) { try { const r = await geoPublish.publish(pool, id); if (r && r.ok) ok++; } catch (e) {} }
          return msg('Published ' + ok + ' of ' + ids.length + ' pages');
        }
        // large batch -> background
        const fs = require('fs'); const tmp = path.join(__dirname, '..', '.geo_bulk_' + Date.now() + '.json');
        fs.writeFileSync(tmp, JSON.stringify(ids));
        const cp = require('child_process'); let out = 'ignore'; try { out = fs.openSync(path.join(__dirname, '..', '.geo_country.log'), 'a'); } catch (e) {}
        const child = cp.spawn(process.execPath, [path.join(__dirname, '..', 'scripts', 'geo_bulk_publish.js'), tmp], { cwd: path.join(__dirname, '..'), detached: true, stdio: ['ignore', out, out], env: process.env });
        child.unref();
        return msg('Publishing ' + ids.length + ' pages in the background — refresh to watch.');
      }
      return res.redirect(back + (back.indexOf('?') >= 0 ? '&' : '?') + 'err=' + enc('Unknown bulk action'));
    } catch (e) { res.redirect('/admin/geo?err=' + enc('Bulk failed: ' + e.message)); }
  });

  router.post('/geo/publish', auth, urlenc, async (req, res) => {
    try { const r = await geoPublish.publish(pool, parseInt(req.body.id, 10)); res.redirect('/admin/geo?ok=' + enc(r.ok ? ('Published ' + r.slug + ' (' + r.indexing + (r.pinged ? ', IndexNow pinged' : '') + ')') : ('Publish failed: ' + r.error))); }
    catch (e) { res.redirect('/admin/geo?err=' + enc('Publish failed: ' + e.message)); }
  });

  router.post('/geo/unpublish', auth, urlenc, async (req, res) => {
    try { const r = await geoPublish.unpublish(pool, parseInt(req.body.id, 10)); res.redirect('/admin/geo?ok=' + enc(r.ok ? ('Unpublished ' + r.slug) : ('Failed: ' + r.error))); }
    catch (e) { res.redirect('/admin/geo?err=' + enc('Unpublish failed: ' + e.message)); }
  });

  router.post('/geo/recompute', auth, urlenc, async (req, res) => {
    try { const r = await geoPublish.recomputeAll(pool); res.redirect('/admin/geo?ok=' + enc('Re-evaluated ' + r.evaluated + ' pages, ' + r.changed + ' index changes')); }
    catch (e) { res.redirect('/admin/geo?err=' + enc('Recompute failed: ' + e.message)); }
  });

  // ============ PRODUCT TARGETING (geo_product_rules) ============
  // A rule is kept only when it changes something (hide / feature / recommend / price / notice);
  // a product left at default has no row, so the table stays a clean exception list.
  function ruleIsDefault(o) {
    return !o.hide && !o.feat && !o.rec && (o.price === '' || o.price == null) && (!o.notice);
  }
  // write one product's rule at one location (delete if default)
  async function writeRule(client, o, locId, defaultCid) {
    await client.query('DELETE FROM geo_product_rules WHERE product_id=$1 AND location_id=$2', [o.pid, locId]);
    if (ruleIsDefault(o)) return 'clear';
    const price = (o.price === '' || o.price == null) ? null : Number(o.price);
    await client.query(
      "INSERT INTO geo_product_rules (product_id, category_id, location_id, availability, enabled, featured, recommended, regional_price, currency_override, special_notice, updated_at) " +
      "VALUES ($1,$2,$3,$4,true,$5,$6,$7,$8,$9,now())",
      [o.pid, o.cid || defaultCid || null, locId, o.hide ? 'unavailable' : 'available', !!o.feat, !!o.rec,
       (price != null && !isNaN(price) && price > 0) ? price : null, o.curOverride || null, o.notice || null]);
    return 'set';
  }

  async function targetData(req) {
    const mode = String(req.query.mode || 'loc') === 'prod' ? 'prod' : 'loc';
    const cats = (await pool.query("SELECT id,slug,name,glyph,sort FROM categories WHERE active ORDER BY sort,name").catch(() => ({ rows: [] }))).rows;
    const products = (await pool.query("SELECT id,name,slug,category_id FROM products WHERE active AND NOT hidden ORDER BY category_id,sort,name").catch(() => ({ rows: [] }))).rows;
    const locs = (await pool.query("SELECT id,type,name,slug,country_code,currency,currency_symbol FROM geo_locations WHERE enabled ORDER BY (type='country') DESC,(type='region') DESC,name").catch(() => ({ rows: [] }))).rows;
    const out = {
      title: 'Product targeting', active: 'geo', mode, cats, products, locs,
      loc: null, locRules: {}, parentCountry: null, prod: null,
      flash: req.query.ok || null, err: req.query.err || null,
      siteUrl: (process.env.SITE_URL || 'https://galaxyzayron.store').replace(/\/+$/, '')
    };
    if (mode === 'loc' && req.query.loc) {
      const lr = await pool.query("SELECT id,type,name,slug,country_code,currency,currency_symbol,parent_id FROM geo_locations WHERE id=$1", [parseInt(req.query.loc, 10)]).catch(() => ({ rows: [] }));
      out.loc = lr.rows[0] || null;
      if (out.loc) {
        const rr = await pool.query("SELECT product_id,availability,featured,recommended,regional_price,currency_override,special_notice FROM geo_product_rules WHERE location_id=$1", [out.loc.id]).catch(() => ({ rows: [] }));
        rr.rows.forEach(r => { out.locRules[r.product_id] = r; });
        if (out.loc.type !== 'country' && out.loc.country_code) {
          const pc = await pool.query("SELECT id,name FROM geo_locations WHERE type='country' AND country_code=$1 LIMIT 1", [out.loc.country_code]).catch(() => ({ rows: [] }));
          out.parentCountry = pc.rows[0] || null;
        }
      }
    }
    if (mode === 'prod' && req.query.prod) {
      const pr = await pool.query("SELECT id,name,slug,category_id FROM products WHERE id=$1", [parseInt(req.query.prod, 10)]).catch(() => ({ rows: [] }));
      out.prod = pr.rows[0] || null;
    }
    return out;
  }

  router.get('/geo/targeting', auth, async (req, res) => {
    try { res.render('admin/geo_targeting', await targetData(req)); }
    catch (e) { res.status(500).send('targeting error: ' + e.message); }
  });

  // Instant save: ONE product's rule at ONE location (click-to-save grid). Returns JSON.
  router.post('/geo/targeting/set', auth, express.json(), async (req, res) => {
    try {
      const b = req.body || {};
      const locId = parseInt(b.loc, 10), pid = parseInt(b.pid, 10);
      if (!locId || !pid) return res.status(400).json({ ok: false, error: 'bad request' });
      const lmeta = await pool.query("SELECT currency_symbol FROM geo_locations WHERE id=$1", [locId]).catch(() => ({ rows: [] }));
      const sym = (lmeta.rows[0] && lmeta.rows[0].currency_symbol) || null;
      const o = {
        pid, cid: parseInt(b.cid, 10) || null,
        hide: !!b.hide, feat: !!b.feat, rec: !!b.rec,
        price: (b.price == null ? '' : String(b.price).trim()),
        notice: (b.notice == null ? '' : String(b.notice).trim()),
        curOverride: sym
      };
      const client = await pool.connect();
      try { await client.query('BEGIN'); const r = await writeRule(client, o, locId, o.cid); await client.query('COMMIT'); res.json({ ok: true, state: r }); }
      catch (e) { try { await client.query('ROLLBACK'); } catch (x) {} res.json({ ok: false, error: e.message }); }
      finally { client.release(); }
    } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
  });

  // Apply ONE product's rule to MANY locations (the by-product bulk assign)
  router.post('/geo/targeting/apply-product', auth, urlenc, async (req, res) => {
    const pid = parseInt(req.body.prod, 10);
    const cid = parseInt(req.body.cid, 10) || null;
    const back = '/admin/geo/targeting?mode=prod&prod=' + pid;
    if (!pid) return res.redirect('/admin/geo/targeting?err=' + enc('No product'));
    const locIds = String(req.body.locs || '').split(',').map(x => parseInt(x, 10)).filter(Boolean);
    if (!locIds.length) return res.redirect(back + '&err=' + enc('Pick at least one location'));
    const o = {
      pid, cid,
      hide: String(req.body.hide || '') === '1',
      feat: String(req.body.feat || '') === '1',
      rec: String(req.body.rec || '') === '1',
      price: String(req.body.price || '').trim(),
      notice: String(req.body.notice || '').trim()
    };
    const lmetas = await pool.query("SELECT id,currency_symbol FROM geo_locations WHERE id=ANY($1)", [locIds]).catch(() => ({ rows: [] }));
    const smap = {}; lmetas.rows.forEach(r => { smap[r.id] = r.currency_symbol || null; });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      let set = 0, cleared = 0;
      for (const locId of locIds) { o.curOverride = smap[locId] || null; const r = await writeRule(client, o, locId, cid); if (r === 'set') set++; else cleared++; }
      await client.query('COMMIT');
      const verb = ruleIsDefault(o) ? ('Cleared the rule at ' + cleared + ' locations') : ('Applied to ' + set + ' locations');
      res.redirect(back + '&ok=' + enc(verb));
    } catch (e) { try { await client.query('ROLLBACK'); } catch (x) {} res.redirect(back + '&err=' + enc('Apply failed: ' + e.message)); }
    finally { client.release(); }
  });

  // ============ PICK PAGES (geo_picks -> PICK_LANDING geo_pages) ============
  function slugify(s) { return String(s || '').toLowerCase().normalize('NFKD').replace(/[^\w\s-]/g, '').trim().replace(/[\s_]+/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, ''); }

  async function picksData(req) {
    const cats = (await pool.query("SELECT id,slug,name,glyph,sort FROM categories WHERE active ORDER BY sort,name").catch(() => ({ rows: [] }))).rows;
    const products = (await pool.query("SELECT id,name,slug,category_id FROM products WHERE active AND NOT hidden ORDER BY category_id,sort,name").catch(() => ({ rows: [] }))).rows;
    const picks = (await pool.query("SELECT * FROM geo_picks ORDER BY created_at DESC").catch(() => ({ rows: [] }))).rows;
    const countries = (await pool.query("SELECT id,name,slug,country_code FROM geo_locations WHERE type='country' AND enabled ORDER BY name").catch(() => ({ rows: [] }))).rows;
    const counts = {};
    const cr = await pool.query("SELECT (content_data->'pick'->>'id') AS pid, status, count(*)::int n FROM geo_pages WHERE page_type='PICK_LANDING' GROUP BY 1,2").catch(() => ({ rows: [] }));
    cr.rows.forEach(r => { if (r.pid == null) return; const id = parseInt(r.pid, 10); counts[id] = counts[id] || { total: 0, live: 0, draft: 0 }; counts[id].total += r.n; if (r.status === 'PUBLISHED') counts[id].live += r.n; else if (r.status === 'DRAFT') counts[id].draft += r.n; });
    return {
      title: 'Pick pages', active: 'geo', cats, products, picks, counts, countries,
      flash: req.query.ok || null, err: req.query.err || null,
      siteUrl: (process.env.SITE_URL || 'https://galaxyzayron.store').replace(/\/+$/, '')
    };
  }

  router.get('/geo/picks', auth, async (req, res) => {
    try { res.render('admin/geo_picks', await picksData(req)); }
    catch (e) { res.status(500).send('picks error: ' + e.message); }
  });

  router.post('/geo/picks/create', auth, urlenc, async (req, res) => {
    try {
      const name = String(req.body.name || '').trim();
      const cid = parseInt(req.body.category_id, 10) || null;
      const ids = String(req.body.product_ids || '').split(',').map(x => parseInt(x, 10)).filter(Boolean);
      const intro = String(req.body.intro || '').trim() || null;
      if (!name) return res.redirect('/admin/geo/picks?err=' + enc('Enter a name'));
      if (!ids.length) return res.redirect('/admin/geo/picks?err=' + enc('Tick at least one product'));
      let slug = slugify(name) || ('pick-' + Date.now());
      if ((await pool.query("SELECT 1 FROM geo_picks WHERE slug=$1", [slug])).rows.length) slug = slug + '-' + Date.now().toString(36).slice(-4);
      await pool.query("INSERT INTO geo_picks (name,slug,category_id,product_ids,intro) VALUES ($1,$2,$3,$4,$5)", [name, slug, cid, ids, intro]);
      res.redirect('/admin/geo/picks?ok=' + enc('Created "' + name + '" (' + ids.length + ' products). Now spread it to locations below.'));
    } catch (e) { res.redirect('/admin/geo/picks?err=' + enc('Create failed: ' + e.message)); }
  });

  router.post('/geo/picks/update', auth, urlenc, async (req, res) => {
    try {
      const id = parseInt(req.body.id, 10);
      const ids = String(req.body.product_ids || '').split(',').map(x => parseInt(x, 10)).filter(Boolean);
      const name = String(req.body.name || '').trim();
      const intro = String(req.body.intro || '').trim() || null;
      if (!id) return res.redirect('/admin/geo/picks?err=' + enc('No pick'));
      if (!ids.length) return res.redirect('/admin/geo/picks?err=' + enc('Tick at least one product'));
      await pool.query("UPDATE geo_picks SET name=COALESCE(NULLIF($2,''),name), product_ids=$3, intro=$4, updated_at=now() WHERE id=$1", [id, name, ids, intro]);
      res.redirect('/admin/geo/picks?ok=' + enc('Updated. Spread again to rebuild its pages with the new products.'));
    } catch (e) { res.redirect('/admin/geo/picks?err=' + enc('Update failed: ' + e.message)); }
  });

  router.post('/geo/picks/spread', auth, urlenc, async (req, res) => {
    try {
      const id = parseInt(req.body.id, 10);
      if (!id) return res.redirect('/admin/geo/picks?err=' + enc('No pick'));
      const target = String(req.body.target || '');
      const cid = parseInt(req.body.country_id, 10) || 0;
      const cities = String(req.body.cities || '') === '1';
      const live = String(req.body.publish || '') === '1';
      let scope;
      if (target === 'all') scope = 'all' + (cities ? ':cities' : '');
      else { if (!cid) return res.redirect('/admin/geo/picks?err=' + enc('Choose a country first')); scope = 'c:' + cid + (cities ? ':cities' : ''); }
      const cp = require('child_process'); const fs = require('fs'); const GSZ = path.join(__dirname, '..');
      let out = 'ignore'; try { out = fs.openSync(path.join(GSZ, '.geo_country.log'), 'a'); } catch (e) {}
      const child = cp.spawn(process.execPath, [path.join(GSZ, 'scripts', 'geo_pick.js'), String(id), scope, live ? '1' : '0'], { cwd: GSZ, detached: true, stdio: ['ignore', out, out], env: process.env });
      child.unref();
      res.redirect('/admin/geo/picks?ok=' + enc('Spreading across ' + (target === 'all' ? 'all countries' : 'the country') + (cities ? ' + cities' : '') + (live ? ', publishing live' : ' as drafts') + ' — refresh in a few seconds.'));
    } catch (e) { res.redirect('/admin/geo/picks?err=' + enc('Spread failed: ' + e.message)); }
  });

  router.post('/geo/picks/delete', auth, urlenc, async (req, res) => {
    try {
      const id = parseInt(req.body.id, 10); if (!id) return res.redirect('/admin/geo/picks?err=' + enc('No pick'));
      const alsoPages = String(req.body.pages || '') === '1';
      if (alsoPages) await pool.query("DELETE FROM geo_pages WHERE page_type='PICK_LANDING' AND (content_data->'pick'->>'id')::int = $1", [id]);
      await pool.query("DELETE FROM geo_picks WHERE id=$1", [id]);
      res.redirect('/admin/geo/picks?ok=' + enc('Deleted' + (alsoPages ? ' pick and its pages' : ' pick (pages kept)')));
    } catch (e) { res.redirect('/admin/geo/picks?err=' + enc('Delete failed: ' + e.message)); }
  });

  return router;
};
