'use strict';
/* lib/geo_world.js — offline world countries + cities (country-state-city).
 * No API, no network, no rate limits. Used by scripts/geo_country.js to turn a
 * country NAME into the country + ALL of its cities for the geo SEO engine.
 *
 *   resolveCountry(name) -> { iso, name, currency, slug } | null
 *   citiesOf(iso)        -> [{ name, slug }]  (deduped by slug, stable order)
 */
let CSC = null;
try { CSC = require('country-state-city'); } catch (e) { CSC = null; }

function slugify(s) {
  return String(s || '').toLowerCase()
    .normalize('NFKD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

// Common everyday names people type that aren't the dataset's exact country name.
const ALIASES = {
  'uk': 'GB', 'u.k.': 'GB', 'britain': 'GB', 'great britain': 'GB', 'england': 'GB',
  'usa': 'US', 'u.s.a.': 'US', 'u.s.': 'US', 'us': 'US', 'america': 'US', 'united states of america': 'US',
  'uae': 'AE', 'u.a.e.': 'AE', 'emirates': 'AE',
  'ksa': 'SA', 'saudi': 'SA', 'saudi arabia': 'SA',
  'south korea': 'KR', 'korea': 'KR', 'north korea': 'KP',
  'russia': 'RU', 'ivory coast': 'CI', 'czech republic': 'CZ', 'turkey': 'TR',
  'holland': 'NL', 'netherlands': 'NL'
};

function available() { return !!CSC; }

function mk(x) { return { iso: x.isoCode, name: x.name, currency: x.currency || null, slug: slugify(x.name) }; }

function resolveCountry(name) {
  if (!CSC) return null;
  const q = String(name || '').trim(); if (!q) return null;
  const low = q.toLowerCase();
  // ISO-2 code typed directly
  if (/^[a-z]{2}$/i.test(q)) { const c = CSC.Country.getCountryByCode(q.toUpperCase()); if (c) return mk(c); }
  // everyday alias
  if (ALIASES[low]) { const c = CSC.Country.getCountryByCode(ALIASES[low]); if (c) return mk(c); }
  const all = CSC.Country.getAllCountries();
  let c = all.find(x => x.name.toLowerCase() === low); if (c) return mk(c);
  c = all.find(x => x.name.toLowerCase().startsWith(low)); if (c) return mk(c);
  c = all.find(x => x.name.toLowerCase().indexOf(low) >= 0); if (c) return mk(c);
  return null;
}

function citiesOf(iso) {
  if (!CSC) return [];
  const raw = CSC.City.getCitiesOfCountry(iso) || [];
  const seen = Object.create(null); const out = [];
  for (let i = 0; i < raw.length; i++) {
    const nm = raw[i] && raw[i].name; if (!nm) continue;
    const slug = slugify(nm); if (!slug || seen[slug]) continue;
    seen[slug] = 1; out.push({ name: nm, slug: slug });
  }
  return out;
}

module.exports = { available, resolveCountry, citiesOf, slugify };
