'use strict';
/* lib/trialspec.js — build the extra generate-trial params a product DECLARES it needs.
 * The bot's /api/products reports needs:[...] per product (synced into bot_products). The trial
 * flow previously ignored that, so variant products (e.g. Mega OTT, needs plan_key+type) could
 * not generate a trial. This derives those params generically from the synced catalog, so any
 * current or future variant product's trial "just works" with no per-product code.
 *
 * Returns only params the product declares needing; for simple products it returns {} (no change).
 * Fail-safe: never throws. */

function asArr(v) { if (Array.isArray(v)) return v; if (typeof v === 'string') { try { const p = JSON.parse(v); return Array.isArray(p) ? p : []; } catch (e) { return []; } } return []; }

async function trialExtras(pool, sku) {
  const out = {};
  try {
    const bp = (await pool.query('SELECT needs, plans, types FROM bot_products WHERE sku=$1', [sku])).rows[0];
    if (!bp) return out;
    const needs = asArr(bp.needs).map(String);

    if (needs.indexOf('plan_key') >= 0) {
      const plans = asArr(bp.plans);
      // the trial plan: explicit plan_key 'trial', else a free plan, else one labelled "trial"
      const tp = plans.find(p => p && (p.plan_key === 'trial' || Number(p.price) === 0 || /trial/i.test(String(p.label || ''))));
      if (tp && tp.plan_key) out.plan_key = tp.plan_key;
    }

    if (needs.indexOf('type') >= 0) {
      const types = asArr(bp.types);
      // default a trial to a non-adult variant (Family), else the first type
      const ft = types.find(t => t && !/adult|xxx|18\+/i.test(String(t.key || '') + ' ' + String(t.label || ''))) || types[0];
      if (ft && ft.key) out.type = ft.key;
    }
  } catch (e) { /* fail-safe: send nothing extra */ }
  return out;
}

module.exports = { trialExtras };
