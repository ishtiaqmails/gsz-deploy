'use strict';
/* GSZ pricing engine (Stage 1) — auto local-currency from a USD base, live FX, owner buffer.
 *
 * Model (matches galaxytools.net, proven):
 *   - Pakistan (PK)  -> always price_pkr, shown as Rs.
 *   - Everyone else  -> a USD base, converted LIVE into the visitor's local currency.
 *       USD base = price_usd if the owner set one (>0), else price_pkr converted to USD
 *                  (safe fallback so a plan without a USD price is never blank).
 *   - Buffer: the owner shaves a % off the converted foreign price (his "285 -> 283"):
 *       final = floor( local * (1 - buffer%) ) rounded to a clean number. PKR is never buffered.
 *
 * Live FX: open.er-api.com/v6/latest/USD (free, no key), cached 12h in memory, with a
 * built-in fallback table so prices NEVER go blank if the API is briefly unreachable.
 * Pure + self-contained. Nothing here touches the live site until Stage 2 wires it in.
 */
const https = require('https');

// country -> ISO currency (common markets; anything not listed falls back to USD)
const CC_CUR = {
  PK:'PKR', US:'USD', GB:'GBP', AE:'AED', SA:'SAR', QA:'QAR', KW:'KWD', OM:'OMR', BH:'BHD',
  IN:'INR', BD:'BDT', LK:'LKR', NP:'NPR', CA:'CAD', AU:'AUD', NZ:'NZD', SG:'SGD', MY:'MYR',
  ID:'IDR', TH:'THB', PH:'PHP', VN:'VND', CN:'CNY', JP:'JPY', KR:'KRW', HK:'HKD', TW:'TWD',
  DE:'EUR', FR:'EUR', IT:'EUR', ES:'EUR', NL:'EUR', BE:'EUR', AT:'EUR', IE:'EUR', PT:'EUR',
  GR:'EUR', FI:'EUR', LU:'EUR', CH:'CHF', SE:'SEK', NO:'NOK', DK:'DKK', PL:'PLN', CZ:'CZK',
  HU:'HUF', RO:'RON', BG:'BGN', TR:'TRY', RU:'RUB', UA:'UAH', ZA:'ZAR', NG:'NGN', KE:'KES',
  GH:'GHS', EG:'EGP', MA:'MAD', DZ:'DZD', TN:'TND', ET:'ETB', TZ:'TZS', UG:'UGX',
  BR:'BRL', MX:'MXN', AR:'ARS', CL:'CLP', CO:'COP', PE:'PEN', VE:'USD', IL:'ILS', JO:'JOD',
  LB:'USD', IQ:'IQD', IR:'USD', AF:'AFN', MM:'MMK', KH:'USD', MO:'MOP', MN:'MNT'
};
const SYMBOL = { PKR:'Rs ', USD:'$', GBP:'£', EUR:'€', AED:'AED ', SAR:'SAR ', INR:'₹',
  CAD:'CA$', AUD:'A$', JPY:'¥', CNY:'CN¥', KRW:'₩', TRY:'₺', BRL:'R$', ZAR:'R ',
  NGN:'₦', RUB:'₽', THB:'฿', PHP:'₱', MYR:'RM ', IDR:'Rp ', BDT:'৳ ' };

// fallback USD-base rates (1 USD = N units) — only used if the live API is unreachable
const FALLBACK = { USD:1, PKR:280, GBP:0.79, EUR:0.92, AED:3.67, SAR:3.75, INR:83, CAD:1.37, AUD:1.52,
  JPY:150, CNY:7.1, KRW:1330, TRY:34, BRL:5.4, ZAR:18, NGN:1550, RUB:92, THB:35, PHP:57, MYR:4.5,
  IDR:15800, BDT:117, SGD:1.34, HKD:7.8, QAR:3.64, KWD:0.31, OMR:0.385, BHD:0.376, CHF:0.88, SEK:10.6,
  NOK:10.8, DKK:6.9, PLN:4, CZK:23, HUF:360, RON:4.6, EGP:49, LKR:300, NPR:133 };

let _rates = null, _at = 0; const TTL = 12 * 60 * 60 * 1000;

function fetchRates() {
  return new Promise(function (resolve) {
    try {
      const r = https.request({ host: 'open.er-api.com', path: '/v6/latest/USD', method: 'GET', timeout: 8000 },
        function (res) { let b = ''; res.setEncoding('utf8'); res.on('data', c => b += c); res.on('end', function () {
          try { const j = JSON.parse(b); resolve(j && j.result === 'success' && j.rates ? j.rates : null); } catch (e) { resolve(null); } }); });
      r.on('error', () => resolve(null));
      r.on('timeout', () => { try { r.destroy(); } catch (e) {} resolve(null); });
      r.end();
    } catch (e) { resolve(null); }
  });
}
async function rates(force) {
  if (!force && _rates && (Date.now() - _at) < TTL) return _rates;
  const live = await fetchRates();
  if (live && live.USD === 1 && live.PKR) { _rates = live; _at = Date.now(); }
  else if (!_rates) { _rates = FALLBACK; _at = Date.now(); } // never leave prices blank
  return _rates;
}
function curFor(cc) { return CC_CUR[String(cc || '').toUpperCase()] || 'USD'; }
function fmt(cur, amt) {
  const sym = SYMBOL[cur] || (cur + ' ');
  const n = amt < 10 ? (Math.round(amt * 100) / 100) : Math.round(amt);
  return sym + Number(n).toLocaleString('en-US');
}

/* resolve one plan for one country.
 *  plan: { price_pkr, price_usd }   country: 'PK'|'GB'|...   opts: { bufferPct }
 *  -> { currency, symbol, amount, display, mode, usd } */
async function resolve(plan, country, opts) {
  opts = opts || {};
  const pkr = Number(plan && plan.price_pkr || 0) || 0;
  const usdSet = Number(plan && plan.price_usd || 0) || 0;
  const cc = String(country || '').toUpperCase();
  if (cc === 'PK') return { currency: 'PKR', symbol: 'Rs ', amount: pkr, display: fmt('PKR', pkr), mode: 'pkr', usd: usdSet || null };

  const R = await rates(false);
  const usdPerPkr = R.PKR ? (1 / R.PKR) : (1 / FALLBACK.PKR);
  const usdBase = usdSet > 0 ? usdSet : +(pkr * usdPerPkr).toFixed(2); // real USD price, else PKR-derived fallback
  const cur = curFor(cc);
  const rate = (R[cur] != null ? R[cur] : (FALLBACK[cur] != null ? FALLBACK[cur] : 1));
  let local = usdBase * rate;
  const buf = Math.max(0, Math.min(90, Number(opts.bufferPct || 0) || 0));
  if (buf) local = local * (1 - buf / 100);          // shave the owner's buffer off
  local = local < 10 ? Math.floor(local * 100) / 100 : Math.floor(local); // round DOWN -> cleaner/lower
  return { currency: cur, symbol: SYMBOL[cur] || (cur + ' '), amount: local, display: fmt(cur, local),
    mode: usdSet > 0 ? 'usd' : 'pkr-fallback', usd: usdBase };
}

module.exports = { resolve, rates, curFor, fmt, CC_CUR, SYMBOL };
