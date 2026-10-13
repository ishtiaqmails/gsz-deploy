'use strict';
/* IPTV Library Engine — the "What's Inside" explorer, rendered INSIDE the store shell
   (store_top / store_bottom) so it shares the site's header, footer, theme and colours.
   These functions return the page BODY only (scoped styles + markup + script); the route
   wraps them in the shell. Dark theme, inherits the store's CSS variables, fully responsive. */

function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function fmt(n) { n = +n || 0; return n >= 1e6 ? (n / 1e6).toFixed(1).replace(/\.0$/, '') + 'M' : n >= 1e3 ? (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'K' : String(n); }

// Scoped styles — everything under .lib, using the store's own theme variables (with fallbacks),
// so a theme change on the site flows straight through. No external fonts (inherits the site font).
const STYLE = `<style>
  .lib{--l-ink:var(--ink,#eef1ff);--l-mut:var(--muted,#8b93bb);--l-line:var(--line,rgba(255,255,255,.09));--l-surf:var(--surface,#111322);--l-b:var(--b,#3b82ff);--l-brand:var(--brand,linear-gradient(100deg,#8b45ff,#3b82ff 55%,#28d6ff));color:var(--l-ink)}
  .lib *{box-sizing:border-box}
  .lib-wrap{max-width:1480px;margin:0 auto;padding:0 clamp(16px,4vw,28px)}
  .lib a{color:inherit;text-decoration:none}
  .lib-hero{padding:26px 0 18px}
  .lib-crumb{color:var(--l-mut);font-size:.9rem}
  .lib-crumb a{color:var(--l-mut)} .lib-crumb a:hover{color:var(--l-ink)}
  .lib-title{font-weight:800;font-size:clamp(1.5rem,3.6vw,2.4rem);letter-spacing:-.02em;margin:.4rem 0 .5rem;line-height:1.1}
  .lib-stats{display:grid;grid-template-columns:repeat(5,1fr);gap:10px;margin-top:6px}
  .lib-stat{background:var(--l-surf);border:1px solid var(--l-line);border-radius:16px;padding:15px 14px}
  .lib-stat b{display:block;font-size:1.5rem;font-weight:800;letter-spacing:-.02em;line-height:1.05}
  .lib-stat span{display:block;margin-top:4px;font-size:.7rem;color:var(--l-mut);text-transform:uppercase;letter-spacing:.07em;font-weight:700}
  .lib-stat.lead{background:var(--l-brand);border:none;color:#fff}
  .lib-stat.lead span{color:rgba(255,255,255,.9)}
  .lib-bar{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin:18px 0 4px}
  .lib-tabs{display:flex;gap:4px;background:rgba(255,255,255,.04);border:1px solid var(--l-line);border-radius:13px;padding:4px}
  .lib-tab{border:none;background:none;font:700 .9rem inherit;color:var(--l-mut);padding:8px 16px;border-radius:9px;cursor:pointer}
  .lib-tab.on{background:var(--l-b);color:#fff}
  .lib-search{flex:1;min-width:180px;display:flex;align-items:center;gap:8px;border:1px solid var(--l-line);border-radius:13px;padding:10px 14px;background:rgba(255,255,255,.03)}
  .lib-search input{border:none;outline:none;font:500 .95rem inherit;flex:1;background:none;color:var(--l-ink)}
  .lib-search input::placeholder{color:var(--l-mut)} .lib-search svg{flex:none;color:var(--l-mut)}
  .lib-frow{display:flex;gap:8px;align-items:center;overflow-x:auto;padding:12px 0;scrollbar-width:none}
  .lib-frow::-webkit-scrollbar{display:none}
  .lib-flabel{flex:none;font:700 .7rem inherit;color:var(--l-mut);text-transform:uppercase;letter-spacing:.07em;padding-right:4px}
  .lib-chip{white-space:nowrap;border:1px solid var(--l-line);background:rgba(255,255,255,.03);color:var(--l-ink);font:600 .83rem inherit;padding:7px 14px;border-radius:999px;cursor:pointer;display:inline-flex;align-items:center;gap:6px}
  .lib-chip.on{background:rgba(59,130,255,.16);border-color:rgba(59,130,255,.5);color:#cfe0ff}
  .lib-chip i{color:var(--l-mut);font-style:normal;font-weight:500}
  .lib-chip.on i{color:#9cc0ff}
  .lib-meta{color:var(--l-mut);font-size:.9rem;margin:14px 0 10px}
  .lib-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:10px;padding-bottom:30px}
  .lib-card{border:1px solid var(--l-line);border-radius:14px;padding:13px 15px;background:var(--l-surf);display:flex;flex-direction:column;gap:8px;min-height:84px;transition:border-color .15s,transform .15s}
  .lib-card:hover{border-color:rgba(59,130,255,.45);transform:translateY(-1px)}
  .lib-nm{font-weight:600;font-size:.95rem;line-height:1.3;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
  .lib-tags{display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin-top:auto}
  .lib-q{font:700 .66rem inherit;color:#cfe0ff;background:rgba(59,130,255,.16);border-radius:6px;padding:2px 7px}
  .lib-ct{font:500 .76rem inherit;color:var(--l-mut)}
  .lib-co{font:600 .66rem inherit;color:#d7ccff;background:rgba(139,69,255,.16);border-radius:6px;padding:2px 7px}
  .lib-ep{font:700 .68rem inherit;color:#9ff0cf;background:rgba(40,214,170,.14);border-radius:6px;padding:2px 7px}
  .lib-more{display:block;margin:6px auto 44px;border:1px solid var(--l-line);background:rgba(255,255,255,.03);color:var(--l-ink);font:700 .95rem inherit;padding:11px 28px;border-radius:12px;cursor:pointer}
  .lib-more:hover{border-color:rgba(59,130,255,.45)}
  .lib-empty{color:var(--l-mut);text-align:center;padding:48px 0}
  /* index grid */
  .lib-panels{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px;padding:18px 0 46px}
  .lib-panel{border:1px solid var(--l-line);border-radius:18px;padding:20px;background:var(--l-surf);transition:border-color .15s,transform .15s}
  .lib-panel:hover{border-color:rgba(59,130,255,.45);transform:translateY(-2px)}
  .lib-panel-nm{font-weight:700;font-size:1.06rem}
  .lib-panel-big{font-size:2rem;font-weight:800;letter-spacing:-.02em;margin:.25rem 0;background:var(--l-brand);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
  .lib-panel-row{display:flex;gap:12px;color:var(--l-mut);font-size:.84rem;font-weight:600}
  @media(max-width:720px){.lib-stats{grid-template-columns:repeat(2,1fr)}.lib-stat.lead{grid-column:1/-1}}
  @media(max-width:560px){.lib-grid{grid-template-columns:repeat(2,1fr)}.lib-stat b{font-size:1.3rem}.lib-tabs{flex:1}.lib-tab{flex:1;padding:8px 6px;text-align:center}}
</style>`;

function heroStats(live, vod, ser, eps) {
  const total = live + vod + ser;
  return `<div class="lib-stats">
    <div class="lib-stat lead"><b>${fmt(total)}</b><span>Total</span></div>
    <div class="lib-stat"><b>${fmt(live)}</b><span>Live TV</span></div>
    <div class="lib-stat"><b>${fmt(vod)}</b><span>Movies</span></div>
    <div class="lib-stat"><b>${fmt(ser)}</b><span>Series</span></div>
    <div class="lib-stat"><b>${fmt(eps)}</b><span>Episodes</span></div>
  </div>`;
}

// ---- single server explorer (body only) ----
function serverExplorerInner(row, base) {
  const cats = row.categories || {};
  const name = esc(row.name || row.server_key);
  const live = +row.raw_live || +row.live_count || 0, vod = +row.raw_vod || +row.vod_count || 0, ser = +row.raw_series || +row.series_count || 0;
  return `${STYLE}
<div class="lib"><div class="lib-wrap">
  <div class="lib-hero">
    <div class="lib-crumb"><a href="/library">Library</a> › ${name}</div>
    <h1 class="lib-title">${name}</h1>
    ${heroStats(live, vod, ser, +row.episode_count || 0)}
    <div class="lib-bar">
      <div class="lib-tabs" id="libTabs">
        <button class="lib-tab on" data-t="live">Live TV</button>
        <button class="lib-tab" data-t="vod">Movies</button>
        <button class="lib-tab" data-t="series">Series</button>
      </div>
      <label class="lib-search"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
        <input id="libQ" placeholder="Search titles…" autocomplete="off"></label>
    </div>
    <div class="lib-frow" id="libCats"></div>
    <div class="lib-frow" id="libCountries"></div>
  </div>
  <div class="lib-meta" id="libMetaText"></div>
  <div class="lib-grid" id="libGrid"></div>
  <button class="lib-more" id="libMore" style="display:none">Show more</button>
</div></div>
<script>
(function(){
  var SERVER=${JSON.stringify(row.server_key)}, BASE=${JSON.stringify(base || '')};
  var CATS=${JSON.stringify(cats)};
  var type='live', cat='', country='', q='', page=1, pages=1, loading=false;
  function g(id){return document.getElementById(id);}
  var grid=g('libGrid'), meta=g('libMetaText'), more=g('libMore');
  function chips(el, obj, cur, onPick){
    var keys=Object.keys(obj||{}).sort(function(a,b){return obj[b]-obj[a];});
    if(!keys.length){ el.style.display='none'; el.innerHTML=''; return; }
    el.style.display='';
    var h='<span class="lib-flabel">'+(el.id==='libCountries'?'Country':'Category')+'</span><button class="lib-chip '+(cur===''?'on':'')+'" data-v="">All</button>';
    keys.forEach(function(k){ h+='<button class="lib-chip '+(cur===k?'on':'')+'" data-v="'+k.replace(/"/g,'&quot;')+'">'+k+' <i>'+obj[k]+'</i></button>'; });
    el.innerHTML=h;
    el.onclick=function(e){var b=e.target.closest('.lib-chip');if(!b)return;onPick(b.getAttribute('data-v'));
      [].forEach.call(el.querySelectorAll('.lib-chip'),function(t){t.classList.remove('on');});b.classList.add('on');};
  }
  function renderFilters(){
    var d=CATS[type]||{};
    var catObj=(d&&d.categories)?d.categories:(d||{});
    var countryObj=(d&&d.countries)?d.countries:{};
    chips(g('libCats'), catObj, cat, function(v){cat=v;load(true);});
    chips(g('libCountries'), countryObj, country, function(v){country=v;load(true);});
  }
  function card(it){
    var qv=it.quality?'<span class="lib-q">'+esc(it.quality.replace(/\\//g,' · '))+'</span>':'';
    var ep=it.episodes?'<span class="lib-ep">'+it.episodes+' eps</span>':'';
    var co=(it.country&&it.country!=='Worldwide')?'<span class="lib-co">'+esc(it.country)+'</span>':'';
    return '<div class="lib-card"><div class="lib-nm">'+esc(it.name||'')+'</div><div class="lib-tags">'+qv+ep+'<span class="lib-ct">'+esc(it.category||'')+'</span>'+co+'</div></div>';
  }
  function esc(s){var d=document.createElement('div');d.textContent=(s==null?'':String(s));return d.innerHTML;}
  function load(reset){
    if(loading)return;loading=true;if(reset){page=1;grid.innerHTML='';}
    var u=BASE+'/iptv/'+encodeURIComponent(SERVER)+'/browse.json?type='+type+'&page='+page+'&size=48'+(cat?'&cat='+encodeURIComponent(cat):'')+(country?'&country='+encodeURIComponent(country):'')+(q?'&q='+encodeURIComponent(q):'');
    fetch(u).then(function(r){return r.json();}).then(function(d){
      loading=false;
      if(!d.ok){grid.innerHTML='<div class="lib-empty">This library is still importing — check back soon.</div>';meta.textContent='';more.style.display='none';return;}
      pages=d.pages;
      if(d.total===0){grid.innerHTML='<div class="lib-empty">No matches.</div>';}
      else{ d.items.forEach(function(it){grid.insertAdjacentHTML('beforeend',card(it));}); }
      meta.textContent=d.total.toLocaleString()+' '+(type==='vod'?'movies':type==='series'?'series':'channels')+(cat?' · '+cat:'')+(country?' · '+country:'')+(q?' · "'+q+'"':'');
      more.style.display=(page<pages)?'block':'none';
    }).catch(function(){loading=false;});
  }
  g('libTabs').addEventListener('click',function(e){var b=e.target.closest('.lib-tab');if(!b)return;
    [].forEach.call(document.querySelectorAll('.lib-tab'),function(t){t.classList.remove('on');});b.classList.add('on');
    type=b.getAttribute('data-t');cat='';country='';renderFilters();load(true);});
  var qt;g('libQ').addEventListener('input',function(e){clearTimeout(qt);q=e.target.value.trim();qt=setTimeout(function(){load(true);},250);});
  more.addEventListener('click',function(){page++;load(false);});
  renderFilters();load(true);
})();
</script>`;
}

// ---- index of all servers (body only) ----
function libraryIndexInner(servers, base) {
  const grand = servers.reduce((a, s) => a + (+s.raw_live || +s.live_count || 0) + (+s.raw_vod || +s.vod_count || 0) + (+s.raw_series || +s.series_count || 0), 0);
  const cards = servers.map(s => {
    const live = +s.raw_live || +s.live_count || 0, vod = +s.raw_vod || +s.vod_count || 0, ser = +s.raw_series || +s.series_count || 0;
    return `<a class="lib-panel" href="/library/${encodeURIComponent(s.server_key)}">
      <div class="lib-panel-nm">${esc(s.name || s.server_key)}</div>
      <div class="lib-panel-big">${fmt(live + vod + ser)}</div>
      <div class="lib-panel-row"><span>${fmt(live)} live</span><span>${fmt(vod)} movies</span><span>${fmt(ser)} series</span></div>
    </a>`;
  }).join('');
  return `${STYLE}
<div class="lib"><div class="lib-wrap">
  <div class="lib-hero">
    <h1 class="lib-title">Library</h1>
    <p class="lib-meta">${servers.length} IPTV service${servers.length === 1 ? '' : 's'} · ${fmt(grand)} channels, movies &amp; series.</p>
  </div>
  <div class="lib-panels">${cards || '<div class="lib-empty">Libraries are importing…</div>'}</div>
</div></div>`;
}

module.exports = { serverExplorerInner, libraryIndexInner };
