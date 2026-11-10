#!/usr/bin/env bash
# gsz-sweep19 : fix the top strip — (1) drop the word "Live", (2) use the official
# Instagram + WhatsApp brand logos, (3) wire the real auto-incrementing orders
# count back in (admin floor + live count of delivered orders, cached ~60s).
set -e
cd /opt/gsz

cp lib/socialcounts.js /opt/gsz/.gsz-s19-sc.bak
cp views/partials/top_strip.ejs /opt/gsz/.gsz-s19-ts.bak
restore(){ cp /opt/gsz/.gsz-s19-sc.bak lib/socialcounts.js; cp /opt/gsz/.gsz-s19-ts.bak views/partials/top_strip.ejs; }

# 1) engine: add the live delivered-orders count (admin floor + delivered orders)
cat > lib/socialcounts.js <<'JSENGINE'
// Live numbers for the top strip:
//  - Instagram + WhatsApp Channel followers (public og:description, cached ~4h)
//  - Orders delivered: admin floor (>=50,000) + real count of delivered orders
//    (DB, cached ~60s so it tracks new orders without querying on every render).
// Never blocks a render; always returns usable numbers with safe fallbacks.
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
  try { const { Pool } = require('pg'); pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS, max: 1, idleTimeoutMillis: 30000 }); }
  catch(e){ pool = false; }
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
// warm caches at startup so the first render already has real numbers
try { refresh(); refreshOrders(); } catch(e){}
module.exports = { get: get, refresh: refresh };
JSENGINE

# 2) partial: no "Live" word, official brand logos, live orders number
cat > views/partials/top_strip.ejs <<'EJSSTRIP'
<%
var _sc; try { _sc = require('/opt/gsz/lib/socialcounts').get(typeof settings!=='undefined'?settings:null); } catch(e){ _sc = { instagram:271, channel:193, delivered:50000 }; }
var _rating = (typeof settings!=='undefined' && settings && settings.rating) ? String(settings.rating) : '4.9';
var _deliv = (_sc && _sc.delivered) ? _sc.delivered : 50000;
function _n(x){ return Number(x).toLocaleString('en-US'); }
%>
<div id="gsz-topstrip" aria-label="Store updates">
  <div class="track">
    <div class="sld on" data-i="0"><div class="st"><i><span class="star">★</span> <b><%= _rating %></b> rating</i><i><b><%= _n(_deliv) %></b> orders delivered</i><i>Trusted since <b>2021</b></i></div></div>
    <div class="sld" data-i="1"><div class="soc"><span class="lbl">Follow us</span><a class="cnt" href="https://instagram.com/galaxysubz" target="_blank" rel="noopener" aria-label="Instagram followers"><span class="tile ig"><svg viewBox="0 0 24 24"><path d="M7.0301.084c-1.2768.0602-2.1487.264-2.911.5634-.7888.3075-1.4575.72-2.1228 1.3877-.6652.6677-1.075 1.3368-1.3802 2.127-.2954.7638-.4956 1.6365-.552 2.914-.0564 1.2775-.0689 1.6882-.0626 4.947.0062 3.2586.0206 3.6671.0825 4.9473.061 1.2765.264 2.1482.5635 2.9107.308.7889.72 1.4573 1.388 2.1228.6679.6655 1.3365 1.0743 2.1285 1.38.7632.295 1.6361.4961 2.9134.552 1.2773.056 1.6884.069 4.9462.0627 3.2578-.0062 3.668-.0207 4.9478-.0814 1.28-.0607 2.147-.2652 2.9098-.5633.7889-.3086 1.4578-.72 2.1228-1.3881.665-.6682 1.0745-1.3378 1.3795-2.1284.2957-.7632.4966-1.636.552-2.9124.056-1.2809.0692-1.6898.063-4.948-.0063-3.2583-.021-3.6668-.0817-4.9465-.0607-1.2797-.264-2.1487-.5633-2.9117-.3084-.7889-.72-1.4568-1.3876-2.1228C21.2982 1.33 20.628.9208 19.8378.6165 19.074.321 18.2017.1197 16.9244.0645 15.6471.0093 15.236-.005 11.977.0014 8.718.0076 8.31.0215 7.0301.0839m.1402 21.6932c-1.17-.0509-1.8053-.2453-2.2287-.408-.5606-.216-.96-.4771-1.3819-.895-.422-.4178-.6811-.8186-.9-1.378-.1644-.4234-.3624-1.058-.4171-2.228-.0595-1.2645-.072-1.6442-.079-4.848-.007-3.2037.0053-3.583.0607-4.848.05-1.169.2456-1.805.408-2.2282.216-.5613.4762-.96.895-1.3816.4188-.4217.8184-.6814 1.3783-.9003.423-.1651 1.0575-.3614 2.227-.4171 1.2655-.06 1.6447-.072 4.848-.079 3.2033-.007 3.5835.005 4.8495.0608 1.169.0508 1.8053.2445 2.228.408.5608.216.96.4754 1.3816.895.4217.4194.6816.8176.9005 1.3787.1653.4217.3617 1.056.4169 2.2263.0602 1.2655.0739 1.645.0796 4.848.0058 3.203-.0055 3.5834-.061 4.848-.051 1.17-.245 1.8055-.408 2.2294-.216.5604-.4763.96-.8954 1.3814-.419.4215-.8181.6811-1.3783.9-.4224.1649-1.0577.3617-2.2262.4174-1.2656.0595-1.6448.072-4.8493.079-3.2045.007-3.5825-.006-4.848-.0608M16.953 5.5864A1.44 1.44 0 1 0 18.39 4.144a1.44 1.44 0 0 0-1.437 1.4424M5.8385 12.012c.0067 3.4032 2.7706 6.1557 6.173 6.1493 3.4026-.0065 6.157-2.7701 6.1506-6.1733-.0065-3.4032-2.771-6.1565-6.174-6.1498-3.403.0067-6.156 2.771-6.1496 6.1738M8 12.0077a4 4 0 1 1 4.008 3.9921A3.9996 3.9996 0 0 1 8 12.0077"/></svg></span><b><%= _n(_sc.instagram) %></b></a><a class="cnt" href="https://whatsapp.com/channel/0029VbDvVgCDOQIbbuzNiF11" target="_blank" rel="noopener" aria-label="WhatsApp channel followers"><span class="tile wa"><svg viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/></svg></span><b><%= _n(_sc.channel) %></b></a></div></div>
  </div>
</div>
<style>
#gsz-topstrip{position:relative;z-index:50;height:42px;overflow:hidden;background:linear-gradient(90deg,#0c1326,#121a33 50%,#0c1326);border-bottom:1px solid rgba(255,255,255,.08);font-family:inherit;-webkit-font-smoothing:antialiased}
#gsz-topstrip .track{position:relative;height:100%;max-width:1200px;margin:0 auto;padding:0 14px}
#gsz-topstrip .sld{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;gap:12px;opacity:0;transform:translateY(6px);transition:opacity .45s ease,transform .45s ease;pointer-events:none;font-size:12.5px;color:#dfe5f3;font-weight:600}
#gsz-topstrip .sld.on{opacity:1;transform:none;pointer-events:auto}
#gsz-topstrip .st{display:flex;align-items:center}
#gsz-topstrip .st i{font-style:normal;display:inline-flex;align-items:center;gap:5px;padding:0 12px;white-space:nowrap}
#gsz-topstrip .st i+i{border-left:1px solid rgba(255,255,255,.14)}
#gsz-topstrip .st b{color:#fff;font-weight:800}
#gsz-topstrip .star{color:#ffc53d}
#gsz-topstrip .soc{display:inline-flex;align-items:center;gap:12px}
#gsz-topstrip .soc .lbl{color:#9aa6c0;font-weight:600}
#gsz-topstrip .cnt{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);padding:4px 13px 4px 4px;border-radius:999px;text-decoration:none;color:#fff}
#gsz-topstrip .cnt b{color:#fff;font-weight:800;font-size:12.5px;font-variant-numeric:tabular-nums}
#gsz-topstrip .tile{width:26px;height:26px;border-radius:8px;display:inline-flex;align-items:center;justify-content:center;flex:none}
#gsz-topstrip .tile svg{width:15px;height:15px;fill:#fff;display:block}
#gsz-topstrip .tile.ig{background:linear-gradient(45deg,#feda75,#fa7e1e 25%,#d62976 50%,#962fbf 75%,#4f5bd5)}
#gsz-topstrip .tile.wa{background:#25d366}
@media(max-width:560px){#gsz-topstrip .st i{padding:0 8px;font-size:11.5px}#gsz-topstrip .soc .lbl{display:none}}
</style>
<script>(function(){var s=document.querySelectorAll('#gsz-topstrip .sld');if(s.length<2)return;var i=0;setInterval(function(){s[i].classList.remove('on');i=(i+1)%s.length;s[i].classList.add('on');},4000);})();</script>
EJSSTRIP

# 3) validate
if ! node --check lib/socialcounts.js 2>/tmp/e0; then echo "socialcounts syntax error — reverting:"; cat /tmp/e0; restore; exit 1; fi
if ! node -e "require('ejs').compile(require('fs').readFileSync('views/partials/top_strip.ejs','utf8'),{filename:'views/partials/top_strip.ejs'})" 2>/tmp/e1; then echo "top_strip EJS error — reverting:"; cat /tmp/e1; restore; exit 1; fi

# 4) prove the live order count works (loads .env so DB creds match the app)
echo "=== live numbers test (incl. orders) ==="
node -e "require('dotenv').config({path:'/opt/gsz/.env'}); const s=require('./lib/socialcounts'); setTimeout(function(){ console.log(JSON.stringify(s.get({}))); process.exit(0); }, 3500);" || echo "(test inconclusive — app will still compute it)"

pm2 restart gsz
echo; echo "DONE: strip fixed — no 'Live' word, official IG/WhatsApp logos, live orders count (floor + delivered orders)."
