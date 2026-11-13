#!/usr/bin/env bash
# gsz-stepB1gTrial : B1G customer lines are package-limited (16K live); trials carry the FULL catalog
# (26K live). Pull B1G's library from a fresh TRIAL line, and cache trials for their REAL validity
# (parsed from "Valid: N Hours") so a dead 6h trial is never reused. Safe: backup,1-match guards,revert.
set -e
cd /opt/gsz
F=lib/iptv/credsource.js
cp "$F" /opt/gsz/.gsz-b1gtrial.bak

cat > /tmp/gsz_b1g_patch.js <<'PATCH'
const fs=require('fs');
const f='/opt/gsz/lib/iptv/credsource.js';
let s=fs.readFileSync(f,'utf8');
function rep(o,n){ const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+': '+o.slice(0,46)); process.exit(5); } s=s.replace(o,n); }

rep("  opts = opts || {};",
"  opts = opts || {};\n  const TRIAL_FIRST = new Set(['SKU-00036']); // customer lines are package-limited here; a trial carries the full catalog\n  const trialFirst = opts.trialFirst || TRIAL_FIRST.has(sku);");

rep("  const cached = (!opts.fresh && !opts.forceTrial) ? cacheGet(sku) : null;\n  // a cached FULL order line is the best source — trust it without a round-trip\n  if (cached && cached.source === 'order') return Object.assign({ ok: true }, cached, { note: 'cached order' });",
"  const cached = (!opts.fresh && !opts.forceTrial) ? cacheGet(sku) : null;\n  if (cached && trialFirst) {\n    // trialFirst panels: a cached trial is the full catalog; a limited order line is not what we want.\n    if (cached.source === 'trial') return Object.assign({ ok: true }, cached, { note: 'cached trial' });\n  } else if (cached && cached.source === 'order') {\n    // a cached FULL order line is the best source — trust it without a round-trip\n    return Object.assign({ ok: true }, cached, { note: 'cached order' });\n  }");

rep("  if (!opts.forceTrial) {", "  if (!opts.forceTrial && !trialFirst) {");

rep("function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }",
"function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }\n\n// Trials are capped by the panel (e.g. 6h) regardless of hours requested, so cache a trial only for\n// its REAL validity (parsed from the delivery text \"Valid: N Hours\"), minus a safety margin.\nfunction trialTtlFor(text, reqHours) {\n  let n = null; const m = String(text || '').match(/valid[^0-9]*(\\d+)\\s*(hour|hr|day)/i);\n  if (m) { n = parseInt(m[1], 10); if (/day/i.test(m[2])) n *= 24; }\n  const hours = n || reqHours || 24;\n  return Math.max(20 * 60 * 1000, hours * 3600 * 1000 - 30 * 60 * 1000);\n}");

rep("  const trialTtl = Math.max(30 * 60 * 1000, (opts.hours || 24) * 3600 * 1000 - 30 * 60 * 1000); // trial life minus 30-min safety\n", "");

rep("const out = Object.assign(c, { source: 'trial', note: 'inline trial' }); cachePut(sku, out, trialTtl); return out;",
"const out = Object.assign(c, { source: 'trial', note: 'inline trial' }); cachePut(sku, out, trialTtlFor(out.raw, opts.hours)); return out;");

rep("const out = Object.assign(c, { source: 'trial', note: 'queued trial ready' }); cachePut(sku, out, trialTtl); return out;",
"const out = Object.assign(c, { source: 'trial', note: 'queued trial ready' }); cachePut(sku, out, trialTtlFor(out.raw, opts.hours)); return out;");

fs.writeFileSync(f,s);
console.log('PATCHED OK');
PATCH

node /tmp/gsz_b1g_patch.js || { echo "patch failed - reverting"; cp /opt/gsz/.gsz-b1gtrial.bak "$F"; exit 1; }
node --check "$F" || { echo "syntax error - reverting"; cp /opt/gsz/.gsz-b1gtrial.bak "$F"; exit 1; }

node -e 'const fs=require("fs");const p="/opt/gsz/lib/iptv/.creds-cache.json";try{const a=JSON.parse(fs.readFileSync(p,"utf8"));delete a["SKU-00036"];fs.writeFileSync(p,JSON.stringify(a));console.log("cleared SKU-00036 cache");}catch(e){console.log("cache clear skip:",e.message);}'

pm2 restart gsz-iptv-worker gsz
echo "DONE: B1G library now pulls from a fresh full-catalog trial."
