'use strict';
/* sku_remap.js — one-time safe migration after the bot assigned real SKUs to products
   that previously had none (e.g. Hexa4K: id 155 was keyed as '155', now 'SKU-00155').
   1) force-sync the catalogue so the new SKU rows exist and old id-fallback rows are missing;
   2) re-point website references (product_plans.bot_sku, trial_servers.sku, bot_type_labels.sku)
      from the OLD sku to the NEW sku, matched by the bot's immutable id (bot_id) — general,
      not hardcoded; 3) drop the orphan bot_products rows. Idempotent: re-running is a no-op. */
const ROOT = process.argv[2] || '/opt/gsz';
try { require(ROOT + '/node_modules/dotenv').config({ path: ROOT + '/.env' }); } catch (e) {}
const { Pool } = require(ROOT + '/node_modules/pg');
const E = process.env;
let pool;
if (E.DATABASE_URL) pool = new Pool({ connectionString: E.DATABASE_URL });
else if (E.DB_HOST || E.DB_NAME || E.DB_USER) pool = new Pool({ host: E.DB_HOST || '127.0.0.1', port: +(E.DB_PORT || 5432), user: E.DB_USER || E.PGUSER, password: (E.DB_PASS || E.DB_PASSWORD || E.PGPASSWORD || '') + '', database: E.DB_NAME || E.PGDATABASE });
else pool = new Pool();

(async () => {
  // 1) refresh catalogue from the bot (brings in the new SKUs, marks old keys missing)
  try {
    const { syncProducts } = require(ROOT + '/lib/botsync');
    const n = await syncProducts(pool);
    console.log('sync: pulled ' + n + ' products from the bot');
  } catch (e) { console.log('sync WARN: ' + e.message + ' (continuing with current bot_products)'); }

  // 2) find old->new remaps by immutable bot_id (old row now missing, new row active, different sku)
  const remaps = (await pool.query(
    `SELECT o.sku AS old_sku, n.sku AS new_sku, n.bot_id
       FROM bot_products o
       JOIN bot_products n ON n.bot_id = o.bot_id AND n.sku <> o.sku AND COALESCE(n.missing,false)=false
      WHERE COALESCE(o.missing,false)=true AND o.bot_id IS NOT NULL`
  )).rows;

  if (!remaps.length) { console.log('no remaps needed — all mappings already point to live SKUs'); await pool.end(); return; }

  for (const r of remaps) {
    const c = await pool.connect();
    try {
      await c.query('BEGIN');
      const p1 = await c.query('UPDATE product_plans SET bot_sku=$1 WHERE bot_sku=$2', [r.new_sku, r.old_sku]);
      // trial_servers.sku is the key — move only if the target doesn't already exist
      let t1 = { rowCount: 0 };
      const exists = (await c.query('SELECT 1 FROM trial_servers WHERE sku=$1', [r.new_sku])).rowCount > 0;
      if (exists) { await c.query('DELETE FROM trial_servers WHERE sku=$1', [r.old_sku]); }
      else { t1 = await c.query('UPDATE trial_servers SET sku=$1 WHERE sku=$2', [r.new_sku, r.old_sku]); }
      let l1 = { rowCount: 0 };
      try { l1 = await c.query('UPDATE bot_type_labels SET sku=$1 WHERE sku=$2', [r.new_sku, r.old_sku]); } catch (e) {}
      // drop the orphaned old catalogue row
      await c.query('DELETE FROM bot_products WHERE sku=$1 AND COALESCE(missing,false)=true', [r.old_sku]);
      await c.query('COMMIT');
      console.log('remapped ' + r.old_sku + ' -> ' + r.new_sku + ' (bot_id ' + r.bot_id + '): plans=' + p1.rowCount + ' trial_servers=' + t1.rowCount + ' type_labels=' + l1.rowCount);
    } catch (e) { try { await c.query('ROLLBACK'); } catch (_) {} console.log('remap FAILED for ' + r.old_sku + ': ' + e.message); }
    finally { c.release(); }
  }
  await pool.end();
  console.log('done');
})().catch(e => { console.error('ERR', e.message); process.exitCode = 1; });
