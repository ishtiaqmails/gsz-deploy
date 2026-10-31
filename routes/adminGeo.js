'use strict';
/* routes/adminGeo.js — admin UI for the Geo Page Engine. Mount at /admin.
 *   GET  /admin/geo                 dashboard: counts + page list + controls
 *   POST /admin/geo/load-locations  load data/geo_locations.json
 *   POST /admin/geo/generate        stage DRAFT pages (category x locations)
 *   POST /admin/geo/publish         publish one page (gate decides index/noindex + IndexNow ping)
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

  async function dashData(flash, err) {
    const [locs, pages] = await Promise.all([
      geoAdmin ? geoAdmin.locationsSummary(pool).catch(() => ({})) : {},
      geoAdmin ? geoAdmin.pagesSummary(pool).catch(() => ({})) : {}
    ]);
    const rows = (await pool.query(
      "SELECT id,slug,title,status,indexing_status,quality_score,duplicate_score,opportunity_score,page_type " +
      "FROM geo_pages ORDER BY (status='PUBLISHED') DESC, opportunity_score DESC NULLS LAST, id DESC LIMIT 500").catch(() => ({ rows: [] }))).rows;
    const cats = (await pool.query("SELECT slug,name FROM categories WHERE active ORDER BY name").catch(() => ({ rows: [] }))).rows;
    return { title: 'Geo SEO Pages', active: 'geo', locs, pages, rows, cats, flash: flash || null, err: err || null, siteUrl: (process.env.SITE_URL || 'https://galaxyzayron.store').replace(/\/+$/, '') };
  }

  router.get('/geo', auth, async (req, res) => {
    try { res.render('admin/geo', await dashData(req.query.ok, req.query.err)); }
    catch (e) { res.status(500).send('geo admin error: ' + e.message); }
  });

  router.post('/geo/load-locations', auth, urlenc, async (req, res) => {
    try { const r = await geoAdmin.loadLocations(pool, DATA); res.redirect('/admin/geo?ok=' + enc('Loaded ' + r.countries + ' countries, ' + r.regions + ' regions, ' + r.cities + ' cities')); }
    catch (e) { res.redirect('/admin/geo?err=' + enc('Load failed: ' + e.message)); }
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

  function enc(s) { return encodeURIComponent(String(s).slice(0, 180)); }
  return router;
};
