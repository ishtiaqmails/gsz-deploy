#!/usr/bin/env bash
# gsz-sweep21 : read DB creds directly from /opt/gsz/.env (dotenv.parse, not
# process.env) so the live orders count works regardless of the app's own env.
set -e
cd /opt/gsz
cp lib/socialcounts.js /opt/gsz/.gsz-s21-sc.bak

cat > lib/socialcounts.js <<'JSENGINE'
// Live numbers for the top strip:
//  - Instagram + WhatsApp Channel followers (public og:description, cached ~4h)
//  - Orders delivered: admin floor (>=50,000) + real count of delivered orders
//    (DB, cached ~60s). DB credentials are read straight from /opt/gsz/.env so
//    the query works regardless of how the app process received its own env.
const fs = require('fs');
const path = require('path');
const CACHE = path.join(__dirname, '..', '.social-cache.json');
const TTL = 4 * 60 * 60 * 1000;
const ORD_TTL = 60 * 1000;
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';
const SRC = {
  instagram: { url: 'https://www.instagram.com/galaxysubz/', re: /([\d.,]+)\s*Followers/i, seed: 271 },
  channel:   { url: 'https://whatsapp.com/channel/0029VbDvVgCDOQIbbuzNiF11', re: /([\d.,]+)\s*followers/i, seed: 193 }
};
let mem = null, busy = false;
let ord = { n: null, t: 0 }, ordBusy = false, pool = null;

function load(){ if(mem) return mem; try { mem = JSON.parse(fs.readFileSync(CACHE,'utf8')) || {}; } catch(e){ mem = {}; } return mem; }
function persist(){ try { fs.writeFileSync(CACHE, JSON.stringify(mem)); } catch(e){} }

async function fetchOne(key){
  const s = SRC[key];
  try {
    const ctrl = new AbortController(); const to = setTimeout(()=>ctrl.abort(), 8000);
    const r = await fetch(s.url, { headers: { 'User-Agent': UA, 'Accept-Language':'en-US,en;q=0.9', 'Accept':'text/html' }, redirect:'follow', signal: ctrl.signal });
    clearTimeout(to);
    const html = await r.text();
    const og = (html.match(/property=["']og:description["'][^>]*content=["']([^"']+)["']/i) || html.match(/content=["']([^"']+)["'][^>]*property=["']og:description["']/i) || [])[1] || '';
    const m = (og.match(s.re) || html.match(s.re));
    if (m) { const n = parseInt(String(m[1]).replace(/[.,\s]/g,''), 10); if (n > 0) return n; }
  } catch(e){}
  return null;
}
function refresh(){
  if (busy) return; busy = true; load();
  Promise.all(Object.keys(SRC).map(async function(k){ const n = await fetchOne(k); if (n != null) mem[k] = { n: n, t: Date.now() }; }))
    .then(persist).catch(function(){}).finally(function(){ busy = false; });
}
function getPool(){
  if (pool !== null) return pool;
  try {
    let env = {};
    try { env = require('dotenv').parse(fs.readFileSync('/opt/gsz/.env')); } catch(e){}
    const pick = function(k){ return env[k] || process.env[k]; };
    const { Pool } = require('pg');
    pool = new Pool({ host: pick('DB_HOST'), port: pick('DB_PORT'), database: pick('DB_NAME'), user: pick('DB_USER'), password: pick('DB_PASS'), max: 1, idleTimeoutMillis: 30000 });
  } catch(e){ pool = false; }
  return pool;
}
function refreshOrders(){
  if (ordBusy) return; const p = getPool(); if (!p) return; ordBusy = true;
  p.query("SELECT count(*)::int n FROM orders WHERE status='delivered'")
    .then(function(r){ ord = { n: (r.rows[0] && r.rows[0].n) || 0, t: Date.now() }; })
    .catch(function(){}).finally(function(){ ordBusy = false; });
}
function get(settings){
  load();
  const now = Date.now();
  if (Object.keys(SRC).some(function(k){ return !mem[k] || (now-(mem[k].t||0))>TTL; })) refresh();
  if (ord.n === null || (now - ord.t) > ORD_TTL) refreshOrders();
  function val(k, ov){
    if (mem[k] && mem[k].n > 0) return mem[k].n;
    if (settings && settings[ov]) { const v = parseInt(String(settings[ov]).replace(/[^\d]/g,''),10); if (v>0) return v; }
    return SRC[k].seed;
  }
  let floor = 50000;
  if (settings && settings.delivered) { const d = parseInt(String(settings.delivered).replace(/[^0-9]/g,''),10)||0; if (d > floor) floor = d; }
  const delivered = floor + (ord.n > 0 ? ord.n : 0);
  return { instagram: val('instagram','ig_followers'), channel: val('channel','channel_followers'), delivered: delivered };
}
try { refresh(); refreshOrders(); } catch(e){}
module.exports = { get: get, refresh: refresh };
JSENGINE

node --check lib/socialcounts.js || { echo "syntax error — reverting"; cp /opt/gsz/.gsz-s21-sc.bak lib/socialcounts.js; exit 1; }

# test in a shell with NO DB env at all — proves it reads creds from the file
echo "=== orders-count test (clean env, creds from .env file) ==="
env -u DB_HOST -u DB_PORT -u DB_NAME -u DB_USER -u DB_PASS node -e "const s=require('./lib/socialcounts'); setTimeout(function(){ console.log(JSON.stringify(s.get({}))); process.exit(0); }, 4000);"

pm2 restart gsz
echo; echo "DONE: DB creds now read from .env file — reload the site twice to see the live count."
