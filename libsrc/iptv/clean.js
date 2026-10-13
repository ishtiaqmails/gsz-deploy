'use strict';
/* IPTV Library Engine — enhance / normalise / de-duplicate.
   Provider libraries are messy: the same channel appears five times as "US| ESPN FHD",
   "ESPN HD", "ESPN ᴴᴰ", "⚽ ESPN", "ESPN [1080]". This collapses them to ONE clean entry
   ("ESPN", with the quality variants it offers), strips country/quality/junk decoration for a
   premium display name, buckets everything into human categories, and de-dupes — so a 200k-row
   raw dump becomes a tight, readable "What's Inside". Pure functions, no I/O: fast and streamable. */

// ---- decoration we strip from a display name (kept as metadata where useful) ----
const QUALITY = /\b(4k|uhd|fhd|full\s*hd|hd|sd|hq|lq|1080p?|720p?|540p?|480p?|360p?|h265|h\.265|hevc|raw|backup|multi|multi-?audio)\b/gi;
const COUNTRY_PREFIX = /^\s*(?:[|(\[]?\s*[A-Z]{2,3}\s*[|)\]:]\s*|[A-Z]{2,3}\s*[-:]\s*)/; // "US| ", "UK: ", "(EN) ", "[AR]-"
const BRACKETS = /[\[(][^\])]*[\])]/g;                 // "[1080]", "(Backup)"
const EMOJI = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F1E6}-\u{1F1FF}\u{2B00}-\u{2BFF}\u{2190}-\u{21FF}\u{FE0F}\u{200D}]/gu;
const FULLWIDTH = /[\u{1D400}-\u{1D7FF}\u{FF00}-\u{FFEF}\u{2460}-\u{24FF}]/gu; // fancy unicode "ᴴᴰ", "①"
const JUNK = /[*~_·•|]+/g;
const QUAL_RANK = { '4k': 5, uhd: 5, fhd: 4, 'full hd': 4, hd: 3, hq: 3, sd: 2, lq: 1 };

function detectQuality(name) {
  const n = name.toLowerCase();
  let best = '', rank = 0;
  (n.match(QUALITY) || []).forEach(q => { const k = q.replace(/\s+/g, ' ').trim(); const r = QUAL_RANK[k] || (/1080/.test(k) ? 4 : /720/.test(k) ? 3 : /480|360|540/.test(k) ? 2 : 0); if (r > rank) { rank = r; best = /1080/.test(k) ? 'FHD' : /720/.test(k) ? 'HD' : /4k|uhd/.test(k) ? '4K' : k.toUpperCase(); } });
  return best;
}

// A premium, human display name: no country tag, no quality, no emoji, no junk, tidy spacing.
function cleanName(raw) {
  let s = String(raw || '').trim();
  s = s.replace(COUNTRY_PREFIX, '');
  s = s.replace(BRACKETS, ' ');
  s = s.replace(EMOJI, ' ').replace(FULLWIDTH, ' ');
  s = s.replace(QUALITY, ' ');
  s = s.replace(JUNK, ' ');
  s = s.replace(/\s{2,}/g, ' ').replace(/^[\s\-–—:]+|[\s\-–—:]+$/g, '').trim();
  return s || String(raw || '').trim();
}

// The de-dupe key: clean name lowercased, accent-folded, non-alphanumerics dropped. "ESPN FHD" and
// "US| espn hd" both fold to "espn" -> one entry.
function dedupeKey(cleaned) {
  return cleaned.toLowerCase().normalize('NFKD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '');
}

// ---- category bucketing: provider group-titles are chaos; map them to a stable human taxonomy ----
const CAT_RULES = [
  ['Sports', /sport|espn|sky\s*sp|bein|dazn|fight|ufc|wwe|nba|nfl|mlb|nhl|cricket|football|soccer|ligue|la\s*liga|serie\s*a|bundesliga|premier|ptv\s*sport|ten\s*sport|willow|golf|tennis|f1|motogp|rugby/i],
  ['News', /news|cnn|bbc\s*news|fox\s*news|al\s*jazeera|sky\s*news|msnbc|bloomberg|cnbc|geo\s*news|ary\s*news|dunya|samaa|aaj/i],
  ['Kids', /kids|cartoon|nick|disney\s*jr|baby|boomerang|pbs\s*kids|junior|cbeebies|toon/i],
  ['Movies', /movie|cinema|film|hbo|starz|showtime|cinemax|mgm|sony\s*max|star\s*movies/i],
  ['Entertainment', /entertain|comedy|drama|hbo|star\s*plus|zee|colors|sony|hum\s*tv|ary\s*digital|geo\s*ent|star\s*world|mbc|general/i],
  ['Documentary', /document|discovery|nat\s*geo|national\s*geographic|history|animal\s*planet|science|investigation/i],
  ['Music', /music|mtv|vevo|vh1|song|radio|hits/i],
  ['Religious', /islam|quran|makkah|madina|peace\s*tv|church|god|gospel|hindu|bhakti|spiritual/i],
  ['Regional', /urdu|hindi|punjabi|pakistan|india|arab|turk|bangla|tamil|telugu|desi|pak\b/i]
];
function bucket(groupTitle, name) {
  const hay = ((groupTitle || '') + ' ' + (name || '')).toLowerCase();
  for (const [label, re] of CAT_RULES) if (re.test(hay)) return label;
  return 'General';
}

// adult content we flag so the store can hide it by default
const ADULT = /\b(xxx|adult|porn|18\+|sex|erotic)\b/i;

/* Collapse a raw stream list into clean, de-duped entries.
   rows: array of { name, category_name?, stream_icon?/cover?, ... }. Returns:
   { items:[{name,key,quality[],category,logo,variants}], categories:{cat:count}, total, raw, dupes, adult } */
function collapse(rows, kind) {
  const map = new Map();
  let adult = 0;
  for (const r of rows) {
    const rawName = r.name || r.title || '';
    if (!rawName) continue;
    if (ADULT.test(rawName) || ADULT.test(r.category_name || '')) { adult++; continue; }
    const clean = cleanName(rawName);
    const key = dedupeKey(clean);
    if (!key) continue;
    const q = detectQuality(rawName);
    const cat = bucket(r.category_name, clean);
    let e = map.get(key);
    if (!e) { e = { name: clean, key, quality: new Set(), category: cat, logo: r.stream_icon || r.cover || '', variants: 0, episodes: 0 }; map.set(key, e); }
    if (q) e.quality.add(q);
    e.variants++;
    if (!e.logo && (r.stream_icon || r.cover)) e.logo = r.stream_icon || r.cover;
    if (kind === 'series' && r.episode_count) e.episodes = Math.max(e.episodes, r.episode_count);
  }
  const items = [...map.values()].map(e => ({ name: e.name, key: e.key, quality: [...e.quality], category: e.category, logo: e.logo, variants: e.variants, episodes: e.episodes || undefined }));
  items.sort((a, b) => a.name.localeCompare(b.name));
  const categories = {};
  items.forEach(i => { categories[i.category] = (categories[i.category] || 0) + 1; });
  return { items, categories, total: items.length, raw: rows.length, dupes: rows.length - items.length - adult, adult };
}

/* Full enhance pass over a fetched library (Xtream fetchAll OR m3u fetchM3U output). */
function enhance(lib) {
  const live = collapse(lib.live || [], 'live');
  const vod = collapse(lib.vod || [], 'vod');
  const series = collapse(lib.series || [], 'series');
  return {
    live, vod, series,
    counts: { live: live.total, vod: vod.total, series: series.total, episodes: (lib.series || []).reduce((n, s) => n + (s.episode_count || 0), 0) },
    rawCounts: { live: (lib.live || []).length, vod: (lib.vod || []).length, series: (lib.series || []).length },
    adult: live.adult + vod.adult + series.adult
  };
}

module.exports = { enhance, collapse, cleanName, dedupeKey, detectQuality, bucket };
