#!/usr/bin/env bash
# gsz-sweep18 : top "updates strip" — rotates (1) stats ★rating/orders/since-2021
# and (2) live Follow-us counts (Instagram + WhatsApp Channel), with clean tiled
# brand icons. Adds a socialcounts engine (cached, auto-refresh, admin override).
# Inserts the strip at the very top site-wide and removes the old mid-page stats.
set -e
cd /opt/gsz
ST=views/partials/store_top.ejs
HM=views/home.ejs

if [ -f lib/socialcounts.js ] && grep -q "top_strip" "$ST"; then echo "sweep18 already applied"; exit 0; fi

cp "$ST" /opt/gsz/.gsz-s18-st.bak
cp "$HM" /opt/gsz/.gsz-s18-hm.bak
restore(){ cp /opt/gsz/.gsz-s18-st.bak "$ST"; cp /opt/gsz/.gsz-s18-hm.bak "$HM"; rm -f lib/socialcounts.js views/partials/top_strip.ejs; }

# 1) the live-count engine
cat > lib/socialcounts.js <<'JSENGINE'
// Live follower counts for the top strip. Fetches the PUBLIC share metadata
// (og:description) of the Instagram profile + WhatsApp channel, parses the
// follower number, caches it to disk, and refreshes lazily (every few hours).
// Never blocks a page render; on any failure it keeps the last good value,
// then an admin override (settings.ig_followers / settings.channel_followers),
// then a seed. This mirrors what WhatsApp/Instagram already show publicly.
const fs = require('fs');
const path = require('path');
const CACHE = path.join(__dirname, '..', '.social-cache.json');
const TTL = 4 * 60 * 60 * 1000; // refresh at most every 4h
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';
const SRC = {
  instagram: { url: 'https://www.instagram.com/galaxysubz/', re: /([\d.,]+)\s*Followers/i, seed: 271 },
  channel:   { url: 'https://whatsapp.com/channel/0029VbDvVgCDOQIbbuzNiF11', re: /([\d.,]+)\s*followers/i, seed: 193 }
};
let mem = null, busy = false;
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
function get(settings){
  load();
  const now = Date.now();
  const stale = Object.keys(SRC).some(function(k){ return !mem[k] || (now - (mem[k].t||0)) > TTL; });
  if (stale) refresh(); // async, non-blocking — this render uses whatever we have now
  function val(k, ov){
    if (mem[k] && mem[k].n > 0) return mem[k].n;
    if (settings && settings[ov]) { const v = parseInt(String(settings[ov]).replace(/[^\d]/g,''),10); if (v>0) return v; }
    return SRC[k].seed;
  }
  return { instagram: val('instagram','ig_followers'), channel: val('channel','channel_followers') };
}
module.exports = { get: get, refresh: refresh };
JSENGINE

# 2) the strip partial (self-contained: markup + CSS + rotation)
cat > views/partials/top_strip.ejs <<'EJSSTRIP'
<%
var _sc; try { _sc = require('/opt/gsz/lib/socialcounts').get(typeof settings!=='undefined'?settings:null); } catch(e){ _sc = { instagram:271, channel:193 }; }
var _rating = (typeof settings!=='undefined' && settings && settings.rating) ? String(settings.rating) : '4.9';
var _dflr = 50000; if (typeof settings!=='undefined' && settings && settings.delivered){ var _d=parseInt(String(settings.delivered).replace(/[^\d]/g,''),10); if(_d>0)_dflr=_d; }
function _n(x){ return Number(x).toLocaleString('en-US'); }
%>
<div id="gsz-topstrip" aria-label="Store updates">
  <div class="track">
    <div class="sld on" data-i="0"><div class="st"><i><span class="star">★</span> <b><%= _rating %></b> rating</i><i><b><%= _n(_dflr) %>+</b> orders delivered</i><i>Trusted since <b>2021</b></i></div></div>
    <div class="sld" data-i="1"><div class="soc"><span class="lbl">Follow us — live</span><a class="cnt" href="https://instagram.com/galaxysubz" target="_blank" rel="noopener" aria-label="Instagram followers"><span class="tile ig"><svg viewBox="0 0 24 24"><path d="M12 2.9c2.94 0 3.29.01 4.45.06 1.07.05 1.65.23 2.04.38.51.2.88.44 1.26.82.38.38.62.75.82 1.26.15.39.33.97.38 2.04.05 1.16.06 1.51.06 4.45s-.01 3.29-.06 4.45c-.05 1.07-.23 1.65-.38 2.04-.2.51-.44.88-.82 1.26-.38.38-.75.62-1.26.82-.39.15-.97.33-2.04.38-1.16.05-1.51.06-4.45.06s-3.29-.01-4.45-.06c-1.07-.05-1.65-.23-2.04-.38-.51-.2-.88-.44-1.26-.82a3.4 3.4 0 01-.82-1.26c-.15-.39-.33-.97-.38-2.04C2.91 15.29 2.9 14.94 2.9 12s.01-3.29.06-4.45c.05-1.07.23-1.65.38-2.04.2-.51.44-.88.82-1.26.38-.38.75-.62 1.26-.82.39-.15.97-.33 2.04-.38C8.71 2.91 9.06 2.9 12 2.9zm0 3.23A5.87 5.87 0 1017.87 12 5.87 5.87 0 0012 6.13zm0 9.68A3.81 3.81 0 1115.81 12 3.81 3.81 0 0112 15.81zm6.1-9.9a1.37 1.37 0 10-1.37 1.37A1.37 1.37 0 0018.1 5.9z"/></svg></span><b><%= _n(_sc.instagram) %></b></a><a class="cnt" href="https://whatsapp.com/channel/0029VbDvVgCDOQIbbuzNiF11" target="_blank" rel="noopener" aria-label="WhatsApp channel followers"><span class="tile wa"><svg viewBox="0 0 24 24"><path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.9c0 1.9.5 3.68 1.46 5.28L2 22l4.95-1.56a9.9 9.9 0 004.5 1.08h.01c5.46 0 9.9-4.44 9.9-9.9 0-2.65-1.03-5.14-2.9-7.01A9.82 9.82 0 0012.04 2zm5.8 14.06c-.24.68-1.42 1.32-1.95 1.36-.5.04-.96.21-3.23-.67-2.73-1.08-4.44-3.86-4.57-4.04-.13-.18-1.1-1.46-1.1-2.79 0-1.33.7-1.98.94-2.25.24-.27.53-.34.7-.34.18 0 .35 0 .5.01.16.01.38-.06.59.45.24.57.8 1.97.87 2.11.07.14.12.31.02.49-.09.18-.14.29-.27.45-.14.16-.29.36-.41.48-.14.14-.28.29-.12.56.16.27.72 1.19 1.55 1.92 1.07.95 1.97 1.25 2.25 1.39.27.14.43.12.59-.07.16-.18.68-.79.86-1.07.18-.27.36-.22.6-.13.25.09 1.57.74 1.84.88.27.14.45.2.52.31.07.12.07.68-.17 1.36z"/></svg></span><b><%= _n(_sc.channel) %></b></a></div></div>
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
#gsz-topstrip .soc{display:inline-flex;align-items:center;gap:10px}
#gsz-topstrip .soc .lbl{color:#9aa6c0;font-weight:600}
#gsz-topstrip .cnt{display:inline-flex;align-items:center;gap:7px;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);padding:4px 12px 4px 4px;border-radius:999px;text-decoration:none;color:#fff}
#gsz-topstrip .cnt b{color:#fff;font-weight:800;font-size:12.5px;font-variant-numeric:tabular-nums}
#gsz-topstrip .tile{width:24px;height:24px;border-radius:7px;display:inline-flex;align-items:center;justify-content:center;flex:none}
#gsz-topstrip .tile svg{width:14px;height:14px;fill:#fff;display:block}
#gsz-topstrip .tile.ig{background:linear-gradient(135deg,#feda75,#fa7e1e 28%,#d62976 58%,#962fbf 80%,#4f5bd5)}
#gsz-topstrip .tile.wa{background:#25d366}
@media(max-width:560px){#gsz-topstrip .st i{padding:0 8px;font-size:11.5px}#gsz-topstrip .soc .lbl{display:none}}
</style>
<script>(function(){var s=document.querySelectorAll('#gsz-topstrip .sld');if(s.length<2)return;var i=0;setInterval(function(){s[i].classList.remove('on');i=(i+1)%s.length;s[i].classList.add('on');},4000);})();</script>
EJSSTRIP

# 3) insert the strip at the very top of <body> (store_top) + remove the old mid-page stats (home)
cat > /tmp/s18edit.js <<'JS'
const fs=require('fs');
const ST='views/partials/store_top.ejs', HM='views/home.ejs';
let st=fs.readFileSync(ST,'utf8'), hm=fs.readFileSync(HM,'utf8');

// insert include right after the opening <body ...> tag
const bodyM = st.match(/<body[^>]*>/i);
if(!bodyM){ console.error('no <body> in store_top'); process.exit(3); }
if((st.match(/<body[^>]*>/ig)||[]).length!==1){ console.error('expected exactly one <body>'); process.exit(3); }
st = st.replace(bodyM[0], bodyM[0] + "\n<%- include('top_strip') %>");

// remove the old mid-page stats band (balanced <div> removal)
const START='<div class="stats reveal" id="statsBand">';
let i=hm.indexOf(START);
if(i<0){ console.error('statsBand not found'); process.exit(4); }
let re=/<\/?div\b[^>]*>/gi; re.lastIndex=i; let depth=0, end=-1, m;
while((m=re.exec(hm))){ if(m[0][1]==='/'){ depth--; if(depth===0){ end=re.lastIndex; break; } } else { depth++; } }
if(end<0){ console.error('could not balance statsBand divs'); process.exit(5); }
hm = hm.slice(0,i) + hm.slice(end);

fs.writeFileSync(ST, st);
fs.writeFileSync(HM, hm);
console.log('store_top + home edited');
JS
node /tmp/s18edit.js || { echo "edit failed — reverting"; restore; exit 1; }

# 4) validate
if ! node --check lib/socialcounts.js 2>/tmp/e0; then echo "socialcounts.js syntax error — reverting:"; cat /tmp/e0; restore; exit 1; fi
for g in views/partials/top_strip.ejs "$ST" "$HM"; do
  if ! node -e "require('ejs').compile(require('fs').readFileSync('$g','utf8'),{filename:'$g'})" 2>/tmp/ee; then echo "EJS compile FAILED $g — reverting:"; cat /tmp/ee; restore; exit 1; fi
done

# 5) can the server actually read the live counts? (reveals Instagram datacenter-block, if any)
echo "=== live-count fetch test (server-side) ==="
node -e "const s=require('./lib/socialcounts'); s.refresh(); setTimeout(function(){ try{ console.log('cache:', require('fs').readFileSync('.social-cache.json','utf8')); }catch(e){ console.log('no cache written yet'); } },9000);" &
TESTPID=$!

pm2 restart gsz
wait $TESTPID 2>/dev/null
echo; echo "DONE: top strip live (stats + live Instagram/WhatsApp counts); old mid-page stats removed."
echo "Note: if the cache above shows only one of the two, the other site blocked the server read — the strip still shows the last good/seed number, and you can set it in admin later."
