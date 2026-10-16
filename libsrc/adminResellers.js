'use strict';
/* Admin — Reseller Panels manager. CRUD for the public /resellers page cards.
   Each panel: name, badge, tagline, features[], image_url, wa_text, currency, tiers[{credits,price}], active, sort. */
const express = require('express');

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '256kb' });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  function parseFeatures(s) {
    return String(s || '').split(/\r?\n/).map(function (x) { return x.trim(); }).filter(Boolean).slice(0, 12);
  }
  function parseTiers(b) {
    const c = [].concat(b.tier_credits || []);
    const p = [].concat(b.tier_price || []);
    const out = [];
    for (let i = 0; i < c.length; i++) {
      const credits = parseInt(c[i], 10);
      const price = parseFloat(p[i]);
      if (credits > 0 && isFinite(price) && price >= 0) out.push({ credits: credits, price: price });
    }
    out.sort(function (a, b) { return a.credits - b.credits; });
    return out.slice(0, 12);
  }

  router.get('/resellers', auth, async (req, res) => {
    const rows = (await pool.query('SELECT * FROM reseller_panels ORDER BY sort, id')).rows;
    res.render('admin/resellers', { rows: rows, flash: req.query.ok || null, active: 'resellers', title: 'Reseller Panels' });
  });

  router.post('/resellers/save', auth, body, async (req, res) => {
    const b = req.body || {};
    const id = parseInt(b.id, 10) || 0;
    const name = (b.name || '').trim();
    if (!name) return res.redirect('/admin/resellers?ok=err');
    const badge = (b.badge || '').trim() || null;
    const tagline = (b.tagline || '').trim() || null;
    const features = JSON.stringify(parseFeatures(b.features));
    const image_url = (b.image_url || '').trim() || null;
    const wa_text = (b.wa_text || '').trim() || null;
    const currency = (b.currency || 'PKR').trim() || 'PKR';
    const tiers = JSON.stringify(parseTiers(b));
    const active = b.active ? true : false;
    const sort = parseInt(b.sort, 10) || 0;
    if (id) {
      await pool.query(
        'UPDATE reseller_panels SET name=$1,badge=$2,tagline=$3,features=$4::jsonb,image_url=$5,wa_text=$6,currency=$7,tiers=$8::jsonb,active=$9,sort=$10 WHERE id=$11',
        [name, badge, tagline, features, image_url, wa_text, currency, tiers, active, sort, id]);
    } else {
      await pool.query(
        'INSERT INTO reseller_panels(name,badge,tagline,features,image_url,wa_text,currency,tiers,active,sort) VALUES($1,$2,$3,$4::jsonb,$5,$6,$7,$8::jsonb,$9,$10)',
        [name, badge, tagline, features, image_url, wa_text, currency, tiers, active, sort]);
    }
    res.redirect('/admin/resellers?ok=' + (id ? 'updated' : 'added'));
  });

  router.post('/resellers/:id/delete', auth, async (req, res) => {
    await pool.query('DELETE FROM reseller_panels WHERE id=$1', [parseInt(req.params.id, 10) || 0]);
    res.redirect('/admin/resellers?ok=deleted');
  });

  return router;
};
