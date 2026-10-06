'use strict';
/* Global phone-number engine (libphonenumber-js). Parses/validates numbers for
   any country, normalizes to E.164, and lists countries with calling codes +
   names for the signup selector. Degrades to digits-only if the lib is missing. */
let lib = null; try { lib = require('libphonenumber-js'); } catch (e) { lib = null; }

function normalize(input, country) {
  input = String(input || '').trim();
  if (lib) {
    try {
      const pn = (input.charAt(0) === '+')
        ? lib.parsePhoneNumberFromString(input)
        : lib.parsePhoneNumberFromString(input, country || undefined);
      if (pn && pn.isValid()) return { ok: true, e164: pn.number, digits: pn.number.replace(/\D/g, ''), country: pn.country || country || '' };
    } catch (e) { /* fall through */ }
  }
  const d = input.replace(/\D/g, '');
  return { ok: false, digits: d, e164: d ? ('+' + d) : '', country: country || '' };
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
