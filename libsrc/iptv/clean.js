'use strict';
/* IPTV Library Engine — enhance / normalise / de-duplicate.
   Provider libraries are messy: the same channel appears five times as "US| ESPN FHD",
   "ESPN HD", "ESPN ᴴᴰ", "⚽ ESPN", "ESPN [1080]". This collapses them to ONE clean entry
   ("ESPN", with the quality variants it offers), strips country/quality/junk decoration for a
   premium display name, buckets everything into human categories, and de-dupes — so a 200k-row
   raw dump becomes a tight, readable "What's Inside". Pure functions, no I/O: fast and streamable. */

// ---- decoration we strip from a display name (kept as metadata where useful) ----
const QUALITY = /\b(4k|uhd|fhd|full\s*hd|hd|sd|hq|lq|1080p?|720p?|540p?|480p?|360p?|240p?|h\.?26[45]|x26[45]|hevc|avc|ts|m3u8|raw|backup|multi(?:-?audio)?|dual(?:-?audio)?|vip|ppv)\b/gi;
const BRACKETS = /[\[({][^\])}]*[\])}]/g;              // "[1080]", "(Backup)", "{EN}"
const EMOJI = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F1E6}-\u{1F1FF}\u{2B00}-\u{2BFF}\u{2190}-\u{21FF}\u{FE0F}\u{200D}\u{E000}-\u{F8FF}]/gu;
const FULLWIDTH = /[\u{1D400}-\u{1D7FF}\u{FF00}-\u{FFEF}\u{2460}-\u{24FF}\u{2070}-\u{209F}\u{1D2C}-\u{1D6A}]/gu; // fancy "ᴴᴰ", "①", superscripts
// decorative symbols providers sprinkle in: box-drawing, arrows, stars, bullets, bars, slashes
const SYMBOLS = /[►▶◀◁◆◇■□▪▫●○◦◉★☆✦✪✯✧♦♣♠♥❤☀⚡✔✓➤➢»«›‹→←↕↔⇒│┃┆┇┊║▌▐▎▏＊*~_•·‣⁃※＃♪♫＼\/<>{}=＝]+/g;

// "channel" rows that are really section separators / headers, e.g. "===== AUSTRALIA =====",
// "---- SPORTS ----", "### VIP ###", or a row with no letters/digits at all. These are dropped.
function isDivider(raw) {
  const s = String(raw || '');
  if (!/[\p{L}\p{N}]/u.test(s)) return true;          // pure symbols / separators
  if (/[=*~#]{3,}|-{4,}|_{3,}/.test(s)) return true;   // runs of divider chars
  if (/([=*~#]\s){3,}/.test(s)) return true;           // spaced dividers "= = = ="
  return false;
}
const LEADING_INDEX = /^\s*[#№]?\s*\d{1,4}\s*[.):\-–—]\s+/;   // "01. ", "#12) ", "003 - "
const PIPES = /[|¦]+/g;
const QUAL_RANK = { '4k': 5, uhd: 5, fhd: 4, 'full hd': 4, hd: 3, hq: 3, sd: 2, lq: 1 };
// only KNOWN geo / language / quality codes are stripped as a leading tag — never a real
// channel prefix like BBC, ARY, PTV, SKY, TNT, FOX, HBO, MTV, etc.
const GEO_CODE = /^(?:US|USA|UK|GB|EN|ENG|EU|AR|ARB|ARABIC|FR|FRA|DE|GER|DEU|ES|ESP|IT|ITA|PT|POR|NL|NLD|PL|POL|TR|TUR|IR|IRN|IN|IND|PK|PAK|BD|BAN|AF|AFG|CA|CAN|AU|AUS|IE|IRL|RO|ROU|GR|GRE|RU|RUS|SE|SWE|NO|NOR|DK|DEN|FI|FIN|BR|BRA|MX|MEX|PH|PHI|ZA|RSA|KSA|UAE|QA|QAT|EG|EGY|KW|LB|JO|IQ|SY|MA|DZ|TN|EXYU|EXUK|LAT|LATINO|NORDIC|BALKAN|VIP|PPV|HD|FHD|UHD|SD|4K|8K|HEVC|H264|H265)$/i;

function detectQuality(name) {
  const n = String(name).toLowerCase();
  let best = '', rank = 0;
  (n.match(QUALITY) || []).forEach(q => { const k = q.replace(/\s+/g, ' ').trim(); const r = QUAL_RANK[k] || (/1080/.test(k) ? 4 : /720/.test(k) ? 3 : /480|360|540|240/.test(k) ? 2 : 0); if (r > rank) { rank = r; best = /1080/.test(k) ? 'FHD' : /720/.test(k) ? 'HD' : /4k|uhd/.test(k) ? '4K' : k.toUpperCase(); } });
  return best;
}

// A premium, human display name: no country/quality tag, no emoji, no symbols, no junk, tidy spacing.
// Idempotent — safe to run again on an already-cleaned name (used at store time AND display time).
function cleanName(raw) {
  let s = String(raw || '').trim();
  s = s.replace(EMOJI, ' ').replace(SYMBOLS, ' ').replace(FULLWIDTH, ' ');
  s = s.replace(LEADING_INDEX, '');
  // strip repeated leading geo/quality tags only (e.g. "US| ", "AR - ", "UK |EN| ") — known codes only
  s = s.replace(/^[\s|:/\-–—.]+/, '');
  let m;
  while ((m = s.match(/^([A-Za-z0-9+]{1,6})\s*[|:/\-–—]+\s*/)) && GEO_CODE.test(m[1])) s = s.slice(m[0].length).replace(/^[\s|:/\-–—.]+/, '');
  // leading bracketed geo/lang tag that was never closed: "[FR Title", "(EN) Title" (known codes only)
  s = s.replace(/^[\[(]\s*([A-Za-z]{2,3})\b[\s\-_:|]*/, (mm, c) => GEO_CODE.test(c) ? '' : mm);
  s = s.replace(BRACKETS, ' ');              // balanced brackets: "[1080]", "(2016)"
  s = s.replace(/[\[\]{}()]/g, ' ');         // any remaining stray / unbalanced brackets
  s = s.replace(/^\d{1,2}\s+(?=\d{3,4}\b)/, ''); // leading index before a year: "1 1960 …" -> "1960 …"
  s = s.replace(QUALITY, ' ');
  s = s.replace(PIPES, ' ');
  s = s.replace(/\.{2,}/g, ' ').replace(/\s{2,}/g, ' ');
  s = s.replace(/^[\s\-–—:|/.,]+|[\s\-–—:|/.,]+$/g, '').replace(/\s{2,}/g, ' ').trim();
  if (s) return s;
  // full clean emptied it (badly-wrapped source) — still return a bracket/symbol-stripped version, not raw junk
  const fb = String(raw || '').replace(EMOJI, ' ').replace(/[\[\]{}()|=~*►▶●★]+/g, ' ').replace(/\s{2,}/g, ' ').trim();
  return fb || String(raw || '').trim();
}

// The de-dupe key: clean name lowercased, accent-folded, non-alphanumerics dropped. "ESPN FHD" and
// "US| espn hd" both fold to "espn" -> one entry.
function dedupeKey(cleaned) {
  return cleaned.toLowerCase().normalize('NFKD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '');
}

// ---- category bucketing: provider group-titles are chaos; map them to a stable human taxonomy ----
const CAT_RULES = [
  ['Sports', /\bsport|espn|sky\s*sp|bein|dazn|fight|ufc|wwe|aew|nba|nfl|mlb|nhl|cricket|football|soccer|ligue|la\s*liga|serie\s*a|bundesliga|premier\s*le|epl|ptv\s*sport|ten\s*sport|willow|golf|tennis|f1|formula\s*1|motogp|rugby|boxing|wrestling|supersport|astro\s*s/i],
  ['Kids', /\bkids|cartoon|nick|disney\s*jr|disney\s*ch|baby|boomerang|pbs\s*kids|junior|cbeebies|\btoon|pogo|chutti|hungama|duck\s*tv/i],
  ['News', /\bnews|cnn|bbc\s*news|fox\s*news|al\s*jazeera|sky\s*news|msnbc|bloomberg|cnbc|geo\s*news|ary\s*news|dunya|samaa|aaj|24\s*news|france\s*24|dw\b|trt\s*world|republic|aajtak|ndtv|times\s*now/i],
  ['Movies', /\bmovie|cinema|\bfilm|hbo|starz|showtime|cinemax|mgm|sony\s*max|star\s*movies|pix|zee\s*cinema|\bvod|\bott/i],
  ['Documentary', /document|discovery|nat\s*geo|national\s*geographic|\bhistory|animal\s*planet|\bscience|investigation|crime|travel|fyi/i],
  ['Kids & Family', /family/i],
  ['Music', /\bmusic|\bmtv|vevo|vh1|\bsong|radio|\bhits|9xm|mtunes|b4u\s*music/i],
  ['Religious', /islam|quran|makkah|madina|peace\s*tv|\bchurch|\bgod\b|gospel|hindu|bhakti|spiritual|hajj|ramadan|aastha|sanskar/i],
  ['Entertainment', /entertain|comedy|\bdrama|star\s*plus|\bzee|colors|\bsony|hum\s*tv|ary\s*digital|geo\s*ent|star\s*world|\bmbc|general|lifestyle|\btv\b|\bhd\b|\bseries\b|show/i]
];
function bucket(groupTitle, name) {
  const hay = ((groupTitle || '') + ' ' + (name || '')).toLowerCase();
  for (const [label, re] of CAT_RULES) if (re.test(hay)) return label;
  return 'General';
}

// ---- country / region detection (group-title first, then a leading name code) ----
const COUNTRIES = [
  ['Pakistan', '🇵🇰', /\b(pak(istan)?|urdu|\bpk\b|lollywood|ptv|geo tv|ary|hum tv|express news|bol\b)\b/i],
  ['India', '🇮🇳', /\b(india|hindi|\bind\b|bollywood|tamil|telugu|kannada|malayalam|marathi|bengali|punjabi|desi|zee|colors|sony|star plus|sun tv)\b/i],
  ['Bangladesh', '🇧🇩', /\b(bangla(desh)?|\bbd\b)\b/i],
  ['Afghanistan', '🇦🇫', /\b(afghan(istan)?|pashto|dari|\baf\b|tolo)\b/i],
  ['Arabic', '🇸🇦', /\b(arab(ic)?|\bksa\b|saudi|\buae\b|dubai|qatar|kuwait|egypt|\bmbc|\bosn|iraq|jordan|lebanon|\bar\b)\b/i],
  ['Turkey', '🇹🇷', /\b(turk(ey|ish)?|\btr\b|trt|bein türk)\b/i],
  ['Iran', '🇮🇷', /\b(iran|persian|farsi|\bir\b)\b/i],
  ['United Kingdom', '🇬🇧', /\b(uk|united kingdom|british|britain|\beng\b|england|sky uk|bbc|itv|channel 4|freeview)\b/i],
  ['USA', '🇺🇸', /\b(usa|u\.s\.a|united states|american|\bus\b|\bamc\b|espn us)\b/i],
  ['Canada', '🇨🇦', /\b(canada|canadian|\bca\b|\bcbc\b)\b/i],
  ['Australia', '🇦🇺', /\b(australia|aussie|\bau\b|\babc au|foxtel)\b/i],
  ['Ireland', '🇮🇪', /\b(ireland|irish|\brte\b)\b/i],
  ['France', '🇫🇷', /\b(france|french|\bfr\b|canal\+|tf1)\b/i],
  ['Germany', '🇩🇪', /\b(german(y)?|deutsch|\bde\b|\brtl\b|sky de)\b/i],
  ['Spain', '🇪🇸', /\b(spain|spanish|españa|\bes\b|movistar)\b/i],
  ['Italy', '🇮🇹', /\b(ital(y|ian|ia)|\bit\b|\brai\b|mediaset)\b/i],
  ['Portugal', '🇵🇹', /\b(portug(al|uese)|\bpt\b|sport tv)\b/i],
  ['Netherlands', '🇳🇱', /\b(netherlands|dutch|holland|\bnl\b)\b/i],
  ['Poland', '🇵🇱', /\b(poland|polsk|polish|\bpl\b)\b/i],
  ['Balkans', '🇷🇸', /\b(balkan|serbia|croatia|bosnia|ex-?yu|\bhrt\b|slovenia|macedonia|montenegro)\b/i],
  ['Albania', '🇦🇱', /\b(albania|shqip|kosov|\bal\b)\b/i],
  ['Romania', '🇷🇴', /\b(romania|\bro\b|digi)\b/i],
  ['Greece', '🇬🇷', /\b(greece|greek|\bgr\b|\bert\b)\b/i],
  ['Russia', '🇷🇺', /\b(russia|russian|\bru\b)\b/i],
  ['Africa', '🌍', /\b(africa|nigeria|ghana|kenya|somali|ethiop|dstv|south africa|\bza\b)\b/i],
  ['Philippines', '🇵🇭', /\b(philippine|filipino|pinoy|\bph\b|gma|abs-?cbn)\b/i],
  ['Latino', '🌎', /\b(latino|mexico|mexican|brazil|brasil|argentina|colombia|chile|espanol|português br)\b/i],
  ['Nordic', '🇸🇪', /\b(nordic|sweden|norway|denmark|finland|svenska|\bse\b|\bno\b|\bdk\b)\b/i]
];
function detectCountry(groupTitle, name) {
  const hay = ((groupTitle || '') + ' ' + (name || ''));
  for (const [label, flag, re] of COUNTRIES) if (re.test(hay)) return { country: label, flag };
  return { country: 'Worldwide', flag: '🌐' };
}

// Series base name: strip the season / episode tail so every episode folds into ONE series.
// "1000 Babies S01 S01 EP01" -> "1000 Babies", "#Love S01 Episode 1" -> "#Love",
// "11.22.63 S01 The Kill Floor" -> "11.22.63". Run on an already-cleaned name.
function seriesBase(nm) {
  let s = String(nm || '');
  s = s.replace(/\s+S\d{1,2}(?:\s+S\d{1,2})?\b[\s\S]*$/i, '');        // " S01 …" (incl. duplicated " S01 S01 …")
  s = s.replace(/\s+Season\s*\d+\b[\s\S]*$/i, '');
  s = s.replace(/\s+(?:EP|Episode|Ep|E)\s*\d{1,3}\b[\s\S]*$/i, '');
  s = s.replace(/\s+\d{1,2}\s*x\s*\d{1,3}\b[\s\S]*$/i, '');           // "1x05 …"
  return s.trim();
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
    if (isDivider(rawName)) continue;   // drop section-separator rows masquerading as channels
    if (ADULT.test(rawName) || ADULT.test(r.category_name || '')) { adult++; continue; }
    const clean = cleanName(rawName);
    const display = kind === 'series' ? (seriesBase(clean) || clean) : clean;  // fold episodes into their series
    const key = dedupeKey(display);
    if (!key) continue;
    const q = detectQuality(rawName);
    const cat = bucket(r.category_name, display);
    const geo = detectCountry(r.category_name, rawName);
    let e = map.get(key);
    if (!e) { e = { name: display, key, quality: new Set(), category: cat, country: geo.country, flag: geo.flag, logo: r.stream_icon || r.cover || '', variants: 0, episodes: 0, rows: 0 }; map.set(key, e); }
    if (q) e.quality.add(q);
    e.variants++; e.rows++;
    if (e.country === 'Worldwide' && geo.country !== 'Worldwide') { e.country = geo.country; e.flag = geo.flag; }
    if (!e.logo && (r.stream_icon || r.cover)) e.logo = r.stream_icon || r.cover;
    if (kind === 'series' && r.episode_count) e.episodes = Math.max(e.episodes, r.episode_count);
  }
  const items = [...map.values()].map(e => ({ name: e.name, key: e.key, quality: [...e.quality], category: e.category, country: e.country, flag: e.flag, logo: e.logo, variants: e.variants, episodes: (kind === 'series' ? (e.episodes || e.rows) : e.episodes) || undefined }));
  items.sort((a, b) => a.name.localeCompare(b.name));
  const categories = {}, countries = {};
  items.forEach(i => { categories[i.category] = (categories[i.category] || 0) + 1; countries[i.country] = (countries[i.country] || 0) + 1; });
  return { items, categories, countries, total: items.length, raw: rows.length, dupes: rows.length - items.length - adult, adult };
}

/* Full enhance pass over a fetched library (Xtream fetchAll OR m3u fetchM3U output). */
function enhance(lib) {
  const live = collapse(lib.live || [], 'live');
  const vod = collapse(lib.vod || [], 'vod');
  const series = collapse(lib.series || [], 'series');
  return {
    live, vod, series,
    counts: { live: live.total, vod: vod.total, series: series.total, episodes: series.items.reduce((n, s) => n + (s.episodes || 0), 0) },
    rawCounts: { live: (lib.live || []).length, vod: (lib.vod || []).length, series: (lib.series || []).length },
    adult: live.adult + vod.adult + series.adult
  };
}

module.exports = { enhance, collapse, cleanName, dedupeKey, detectQuality, bucket, detectCountry, isDivider, seriesBase };
