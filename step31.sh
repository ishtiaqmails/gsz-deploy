#!/usr/bin/env bash
# STEP 31 (DEBUG): log exactly what /admin/mapping POST receives + writes.
# Temporary diagnostic for the "Save -> reverts to Manual" bug. Auto-rollback.
set -euo pipefail
APP=/opt/gsz
[ -f "$APP/routes/adminMapping.js" ] || { echo "ABORT: adminMapping.js not found"; exit 1; }
cd "$APP"
set -a; . "$APP/.env"; set +a
TS=$(date +%s); BK="$APP/.bak-step31-$TS"; mkdir -p "$BK"
cp routes/adminMapping.js "$BK/adminMapping.js"
restore(){ echo "!! ROLLBACK"; cp "$BK/adminMapping.js" "$APP/routes/adminMapping.js" 2>/dev/null||true; pm2 restart gsz >/dev/null 2>&1||true; }
trap 'restore' ERR
echo "== Step 31 (mapping POST debug logging) =="
cat > routes/adminMapping.js <<'EOF_ADMIN'
'use strict';
/* Admin: map each site PLAN to how it is fulfilled.
   source = manual | inventory | bot.
   For bot plans we store the IMMUTABLE bot_sku (+ bot_plan_key + bot_type),
   never the serial/name/position — so re-ordering on the bot can't break it. */
const express = require('express');
const botapi = require('../lib/botapi');

module.exports = function (pool) {
  const router = express.Router();
  function auth(req, res, next) {
    if (req.session && req.session.admin) return next();
    return res.redirect('/admin/login');
  }

  router.get('/mapping', auth, async (req, res) => {
    try {
      const products = (await pool.query(
        `SELECT p.id, p.name, p.slug, c.name AS cat
           FROM products p LEFT JOIN categories c ON c.id = p.category_id
          WHERE p.active ORDER BY p.sort, p.id`)).rows;
      const plans = (await pool.query(
        `SELECT id, product_id, label, price_pkr, source, bot_sku, bot_plan_key, bot_type
           FROM product_plans ORDER BY product_id, sort, id`)).rows;
      const bots = (await pool.query(
        `SELECT sku, name, serial, delivery_type, price_pkr, is_active,
                needs, plans, types, missing
           FROM bot_products ORDER BY missing, name NULLS LAST, sku`)).rows;
      const invRows = (await pool.query(
        `SELECT plan_id, count(*)::int n FROM inventory_items
          WHERE status='available' GROUP BY plan_id`)).rows;
      const inv = {}; invRows.forEach(r => { inv[r.plan_id] = r.n; });
      const byProd = {}; plans.forEach(pl => { (byProd[pl.product_id] = byProd[pl.product_id] || []).push(pl); });
      const botBySku = {}; bots.forEach(b => { botBySku[b.sku] = b; });

      const ping = await botapi.ping();
      const last = (await pool.query("SELECT value FROM settings WHERE key='bot_last_sync'")).rows[0];

      res.render('admin/mapping', {
        products, byProd, bots, botBySku, inv,
        bot: Object.assign({ last_sync: last ? last.value : null, count: bots.length, missing: bots.filter(b => b.missing).length }, ping),
        flash: req.query.ok || null, active: 'mapping', title: 'Bot mapping'
      });
    } catch (e) { res.status(500).send('Mapping error: ' + e.message); }
  });

  router.post('/mapping', auth, express.urlencoded({ extended: true, limit: '2mb' }), async (req, res) => {
    const pl = (req.body && req.body.pl) || {};
    try { console.log('[MAPPING-POST] rows=' + Object.keys(pl).length + ' data=' + JSON.stringify(pl)); } catch(e){}
    const SRC = ['manual', 'inventory', 'bot'];
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      for (const id of Object.keys(pl)) {
        const pid = parseInt(id, 10); if (!Number.isFinite(pid)) continue;
        const r = pl[id] || {};
        let source = SRC.includes(String(r.source || '')) ? r.source : 'manual';
        const skuRaw = (String(r.bot_sku || '').trim());
        // Robustness: choosing a bot product IS a bot mapping. Never let a stale
        // "Manual" on the Source dropdown silently drop the SKU the admin picked.
        // (The UI also clears the SKU when the admin switches away from bot, so a
        //  leftover value can't force bot by mistake.)
        if (skuRaw) source = 'bot';
        let sku = null, pk = null, ty = null;
        if (source === 'bot') {
          sku = skuRaw || null;
          pk = (String(r.bot_plan_key || '').trim()) || null;
          ty = (String(r.bot_type || '').trim()) || null;
          // keep source='bot' even with no SKU yet, so it stays "bot (not mapped)"
          // instead of silently reverting to Manual.
        }
        console.log('[MAPPING-POST] write id=' + pid + ' source=' + source + ' sku=' + (sku||'(null)'));
        await client.query(
          'UPDATE product_plans SET source=$1, bot_sku=$2, bot_plan_key=$3, bot_type=$4 WHERE id=$5',
          [source, sku, pk, ty, pid]
        );
      }
      await client.query('COMMIT');
      res.redirect('/admin/mapping?ok=' + encodeURIComponent('Mapping saved'));
    } catch (e) {
      try { await client.query('ROLLBACK'); } catch (x) {}
      res.status(500).send('Mapping save error: ' + e.message);
    } finally { client.release(); }
  });

  return router;
};

EOF_ADMIN
node --check routes/adminMapping.js && echo "[ok] syntax" || { echo "ABORT syntax"; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 start server.js --name gsz >/dev/null 2>&1
sleep 2
echo "[ok] debug build live. Now: open /admin/mapping, map Prime Video, click Save mapping, then run:"
echo "   pm2 logs gsz --nostream --lines 60 | grep MAPPING-POST"
trap - ERR
echo "== Step 31 DONE (remember: this is temporary debug) =="
