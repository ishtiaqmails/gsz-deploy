'use strict';
/* BOT_TRIAL_GATE_v2 — the trial gate keyed its map on the bot's `sku`, which is null
   for id-only products (e.g. Hexa4K, id=155), so their trial was hidden even when enabled
   on both sides. Resolve the key as sku -> code -> String(id), exactly like lib/botsync.skuOf,
   so trial_servers.sku (stored via the same fallback) matches. In-place, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const file = path.join(ROOT, 'routes/trials.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('BOT_TRIAL_GATE_v2') >= 0) { console.log('BOT_TRIAL_GATE_v2 already present — skip'); process.exit(0); }

const OLD = "(Array.isArray(prods) ? prods : []).forEach(function (p) { if (p && p.sku && p.trial) m[p.sku] = p.trial; });";
const NEW = "(Array.isArray(prods) ? prods : []).forEach(function (p) { if (!p || !p.trial) return; var k = (p.sku != null && String(p.sku).trim() !== '') ? String(p.sku).trim() : (p.code != null && String(p.code).trim() !== '') ? String(p.code).trim() : (p.id != null ? String(p.id) : null); if (k) m[k] = p.trial; /* BOT_TRIAL_GATE_v2: id-fallback key, matches botsync skuOf */ });";

if (s.indexOf(OLD) < 0) throw new Error('trial-gate anchor not found (expected v1 forEach line)');
s = s.replace(OLD, NEW);
fs.writeFileSync(file, s);
console.log('BOT_TRIAL_GATE_v2 applied');
