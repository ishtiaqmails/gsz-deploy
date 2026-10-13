'use strict';
/* Global phone-number engine (libphonenumber-js). Parses/validates numbers for
   any country, normalizes to E.164, and lists countries with calling codes +
   names for the signup selector. Degrades GRACEFULLY: if the library is missing
   or can't validate a given number, a plausible-length number is still accepted
   (ok:true) so real customers are never blocked from signing up. */
let lib = null; try { lib = require('libphonenumber-js'); } catch (e) { lib = null; }

// A number is "plausible" when it has an international-sized digit count.
function lenientOk(d) { return d.length >= 8 && d.length <= 15; }

function normalize(input, country) {
  input = String(input || '').trim();
  if (lib) {
    try {
      const pn = (input.charAt(0) === '+')
        ? lib.parsePhoneNumberFromString(input)
        : lib.parsePhoneNumberFromString(input, country || undefined);
      if (pn && pn.isValid()) return { ok: true, e164: pn.number, digits: pn.number.replace(/\D/g, ''), country: pn.country || country || '' };
      // libphonenumber couldn't confirm it — fall through to the lenient check instead of hard-rejecting,
      // but keep its best-effort E.164 when it managed to build one.
      if (pn && pn.number) { const d0 = pn.number.replace(/\D/g, ''); return { ok: lenientOk(d0), e164: pn.number, digits: d0, country: pn.country || country || '' }; }
    } catch (e) { /* fall through to lenient */ }
  }
  // lib missing OR parse failed: accept a plausible international number so signup isn't blocked.
  const d = input.replace(/\D/g, '');
  return { ok: lenientOk(d), digits: d, e164: d ? ('+' + d) : '', country: country || '' };
}

let _cache = null;
function countries() {
  if (_cache) return _cache;
  if (!lib) return [];
  let dn = null; try { dn = new Intl.DisplayNames(['en'], { type: 'region' }); } catch (e) {}
  try {
    _cache = lib.getCountries().map(iso => ({ iso, code: lib.getCountryCallingCode(iso), name: (dn ? dn.of(iso) : iso) || iso }))
      .sort((a, b) => a.name.localeCompare(b.name));
    return _cache;
  } catch (e) { return []; }
}

module.exports = { normalize, countries };
