'use strict';
/* Coupon engine. validate() checks a code against a PKR subtotal and returns
   the discount (percent or fixed), honoring min order, expiry, usage limit and
   active flag. Amounts are in PKR (the storefront's base currency). */
async function validate(pool, code, subtotalPkr) {
  code = String(code || '').trim().toUpperCase();
  if (!code) return { ok: false, reason: 'Enter a discount code.' };
  let c;
  try { c = (await pool.query('SELECT * FROM coupons WHERE upper(code)=$1', [code])).rows[0]; } catch (e) { c = null; }
  if (!c || !c.active) return { ok: false, reason: 'That code is not valid.' };
  if (c.expires_at && new Date(c.expires_at) < new Date()) return { ok: false, reason: 'That code has expired.' };
  if (c.usage_limit != null && Number(c.used_count) >= Number(c.usage_limit)) return { ok: false, reason: 'That code has reached its limit.' };
  const sub = Number(subtotalPkr) || 0;
  if (c.min_order_pkr && sub < Number(c.min_order_pkr)) return { ok: false, reason: 'Minimum order Rs ' + Math.round(c.min_order_pkr).toLocaleString('en-US') + ' for this code.' };
  let disc = (c.kind === 'percent') ? sub * (Number(c.value) / 100) : Number(c.value);
  if (c.max_discount_pkr && disc > Number(c.max_discount_pkr)) disc = Number(c.max_discount_pkr);
  disc = Math.max(0, Math.min(disc, sub));
  const label = (c.kind === 'percent') ? (Number(c.value) + '% off') : ('Rs ' + Math.round(c.value).toLocaleString('en-US') + ' off');
  return { ok: true, discountPkr: Math.round(disc), code: c.code, label: label, couponId: c.id };
}

module.exports = { validate };
