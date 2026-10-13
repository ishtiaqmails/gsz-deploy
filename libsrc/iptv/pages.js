'use strict';
/* IPTV Library Engine — "What's Inside" explorer. Premium, light, white. Browse by type, category
   and country, with instant search. Server-rendered shell (counts + filters embedded for instant
   paint) + a browse API for paging. Self-contained HTML. Also renders a compact embeddable block
   for the product page. */

function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function fmt(n) { n = +n || 0; return n >= 1e6 ? (n / 1e6).toFixed(1).replace(/\.0$/, '') + 'M' : n >= 1e3 ? (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'K' : String(n); }

const STYLE = `<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  :root{--ink:#0e1117;--muted:#616b7a;--faint:#9aa3b2;--line:#eceef3;--bg:#fff;--soft:#f6f7fb;--accent:#5b3df5;--accent2:#9a6bff;--chip:#f0edff;--chipbd:#ddd6fb;--ok:#0ea06a}
  *{box-sizing:border-box}html{-webkit-text-size-adjust:100%}
  body{margin:0;background:var(--bg);color:var(--ink);font-family:Inter,system-ui,sans-serif;-webkit-font-smoothing:antialiased;line-height:1.5}
  a{color:inherit;text-decoration:none}
  .wrap{max-width:1200px;margin:0 auto;padding:0 20px}
  .disp{font-family:'Space Grotesk',Inter,sans-serif}
  .topbar{border-bottom:1px solid var(--line);background:#fff}
  .topbar .wrap{display:flex;align-items:center;gap:14px;height:58px}
  .brand{font-family:'Space Grotesk';font-weight:700;font-size:1.05rem;letter-spacing:-.01em}
  .brand b{background:linear-gradient(135deg,var(--accent),var(--accent2));-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
  .topbar .sp{flex:1}
  .topbar a.nav{color:var(--muted);font-weight:500;font-size:.92rem}
  .hero{position:relative;overflow:hidden;border-bottom:1px solid var(--line);background:
     radial-gradient(1100px 380px at 88% -20%,rgba(154,107,255,.12),transparent 60%),
     radial-gradient(760px 300px at 2% -30%,rgba(91,61,245,.09),transparent 60%),#fff}
  .hero .wrap{padding:30px 20px 26px}
  .crumb{color:var(--muted);font-weight:500;font-size:.88rem}
  .title{font-weight:700;font-size:clamp(1.7rem,3.8vw,2.7rem);letter-spacing:-.02em;margin:.45rem 0 .15rem}
  .sub{color:var(--muted);max-width:640px;font-size:.96rem}
  .stats{display:flex;flex-wrap:wrap;gap:10px;margin-top:20px}
  .stat{flex:1 1 130px;min-width:120px;border:1px solid var(--line);border-radius:15px;padding:14px 16px;background:#fff}
  .stat b{font-family:'Space Grotesk';display:block;font-size:1.6rem;font-weight:700;letter-spacing:-.02em;line-height:1}
  .stat span{color:var(--muted);font-size:.78rem;font-weight:600;text-transform:uppercase;letter-spacing:.05em}
  .stat.lead{background:linear-gradient(135deg,var(--accent),var(--accent2));border:none;color:#fff}
  .stat.lead span{color:rgba(255,255,255,.88)}
  .bar{position:sticky;top:0;z-index:5;background:rgba(255,255,255,.9);backdrop-filter:blur(10px);border-bottom:1px solid var(--line)}
  .bar .wrap{display:flex;gap:12px;align-items:center;padding:11px 20px;flex-wrap:wrap}
  .tabs{display:flex;gap:4px;background:var(--soft);border-radius:12px;padding:4px}
  .tab{border:none;background:none;font:600 .9rem Inter;color:var(--muted);padding:8px 15px;border-radius:9px;cursor:pointer}
  .tab.on{background:#fff;color:var(--ink);box-shadow:0 1px 3px rgba(16,17,23,.09)}
  .search{flex:1;min-width:170px;display:flex;align-items:center;gap:8px;border:1px solid var(--line);border-radius:12px;padding:9px 13px;background:#fff}
  .search input{border:none;outline:none;font:500 .95rem Inter;flex:1;background:none;color:var(--ink)}
  .search svg{flex:none;color:var(--faint)}
  .filters{border-bottom:1px solid var(--line)}
  .frow{display:flex;gap:8px;align-items:center;overflow-x:auto;padding:11px 0;scrollbar-width:none}
  .frow::-webkit-scrollbar{display:none}
  .flabel{flex:none;font:600 .72rem Inter;color:var(--faint);text-transform:uppercase;letter-spacing:.06em;padding-right:4px}
  .chip{white-space:nowrap;border:1px solid var(--line);background:#fff;color:var(--ink);font:600 .83rem Inter;padding:6px 13px;border-radius:999px;cursor:pointer;display:inline-flex;align-items:center;gap:6px}
  .chip.on{background:var(--chip);border-color:var(--chipbd);color:var(--accent)}
  .chip i{color:var(--faint);font-style:normal;font-weight:500}
  .chip.on i{color:var(--accent)}
  .meta{color:var(--muted);font-size:.9rem;margin:16px 0 8px}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px;padding-bottom:28px}
  .card{border:1px solid var(--line);border-radius:13px;padding:13px 15px;background:#fff;display:flex;flex-direction:column;gap:7px;transition:border-color .15s,transform .15s,box-shadow .15s}
  .card:hover{border-color:var(--chipbd);transform:translateY(-1px);box-shadow:0 6px 20px rgba(91,61,245,.07)}
  .nm{font-weight:600;font-size:.95rem;line-height:1.3;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
  .nm .fl{margin-right:5px}
  .tags{display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin-top:auto}
  .q{font:600 .68rem Inter;color:var(--accent);background:var(--chip);border-radius:6px;padding:2px 7px;letter-spacing:.02em}
  .ct{font:500 .76rem Inter;color:var(--faint)}
  .co{font:600 .68rem Inter;color:#6b5bd1;background:#efecfd;border-radius:6px;padding:2px 7px}
  .ep{font:600 .7rem Inter;color:var(--ok);background:#e9f8f1;border-radius:6px;padding:2px 7px}
  .more{display:block;margin:4px auto 44px;border:1px solid var(--line);background:#fff;color:var(--ink);font:600 .95rem Inter;padding:11px 26px;border-radius:12px;cursor:pointer}
  .more:hover{border-color:var(--chipbd)}
  .empty{color:var(--muted);text-align:center;padding:48px 0}
  .foot{border-top:1px solid var(--line);color:var(--faint);font-size:.85rem;padding:22px 0}
  @media(max-width:640px){.stat b{font-size:1.35rem}.grid{grid-template-columns:repeat(auto-fill,minmax(150px,1fr))}}
</style>`;

function topbar() {
  return `<header class="topbar"><div class="wrap"><a class="brand disp" href="/library">Galaxy&nbsp;Subz <b>×</b> Zayron · <span style="color:var(--muted);font-weight:600">Library</span></a><span class="sp"></span><a class="nav" href="/">← Store</a></div></header>`;
}

function serverExplorerHtml(row, base) {
  const cats = row.categories || {};
  const name = esc(row.name || row.server_key);
  const updated = row.updated_at ? new Date(row.updated_at).toISOString().slice(0, 10) : '';
  const live = +row.raw_live || +row.live_count || 0, vod = +row.raw_vod || +row.vod_count || 0, ser = +row.raw_series || +row.series_count || 0;
  const total = live + vod + ser;
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${name} — What's Inside | Galaxy Subz × Zayron</title>
<meta name="description" content="Browse everything inside ${name}: ${fmt(live)} live channels, ${fmt(vod)} movies and ${fmt(ser)} series across every category and country.">
${STYLE}</head><body>
${topbar()}
<section class="hero"><div class="wrap">
  <div class="crumb"><a href="/library" style="color:var(--muted)">All servers</a> › ${name}</div>
  <h1 class="title disp">${name}</h1>
  <p class="sub">Every live channel, movie and series inside this server — cleaned, de-duplicated and organised by category and country. Updated ${updated}.</p>
  <div class="stats">
    <div class="stat lead"><b>${fmt(total)}</b><span>Total titles</span></div>
    <div class="stat"><b>${fmt(live)}</b><span>Live TV</span></div>
    <div class="stat"><b>${fmt(vod)}</b><span>Movies</span></div>
    <div class="stat"><b>${fmt(ser)}</b><span>Series</span></div>
    <div class="stat"><b>${fmt(row.episode_count)}</b><span>Episodes</span></div>
  </div>
</div></section>
<div class="bar"><div class="wrap">
  <div class="tabs" id="tabs">
    <button class="tab on" data-t="live">Live TV</button>
    <button class="tab" data-t="vod">Movies</button>
    <button class="tab" data-t="series">Series</button>
  </div>
  <label class="search"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
    <input id="q" placeholder="Search titles…" autocomplete="off"></label>
</div></div>
<div class="filters"><div class="wrap">
  <div class="frow" id="cats"></div>
  <div class="frow" id="countries"></div>
</div></div>
<main class="wrap">
  <div class="meta" id="meta"></div>
  <div class="grid" id="grid"></div>
  <button class="more" id="more" style="display:none">Show more</button>
</main>
<footer class="foot"><div class="wrap">Galaxy Subz × Zayron — live library, refreshed automatically.</div></footer>
<script>
  var SERVER=${JSON.stringify(row.server_key)}, BASE=${JSON.stringify(base || '')};
  var CATS=${JSON.stringify(cats)};
  var FLAGS={'Pakistan':'🇵🇰','India':'🇮🇳','Bangladesh':'🇧🇩','Afghanistan':'🇦🇫','Arabic':'🇸🇦','Turkey':'🇹🇷','Iran':'🇮🇷','United Kingdom':'🇬🇧','USA':'🇺🇸','Canada':'🇨🇦','Australia':'🇦🇺','Ireland':'🇮🇪','France':'🇫🇷','Germany':'🇩🇪','Spain':'🇪🇸','Italy':'🇮🇹','Portugal':'🇵🇹','Netherlands':'🇳🇱','Poland':'🇵🇱','Balkans':'🇷🇸','Albania':'🇦🇱','Romania':'🇷🇴','Greece':'🇬🇷','Russia':'🇷🇺','Africa':'🌍','Philippines':'🇵🇭','Latino':'🌎','Nordic':'🇸🇪','Worldwide':'🌐'};
  var type='live', cat='', country='', q='', page=1, pages=1, loading=false;
  var grid=g('grid'), meta=g('meta'), more=g('more');
  function g(id){return document.getElementById(id);}
  function chips(el, obj, cur, flags, onPick){
    var keys=Object.keys(obj||{}).sort(function(a,b){return obj[b]-obj[a];});
    var h='<span class="flabel">'+(flags?'Country':'Category')+'</span><button class="chip '+(cur===''?'on':'')+'" data-v="">All</button>';
    keys.forEach(function(k){ h+='<button class="chip '+(cur===k?'on':'')+'" data-v="'+k.replace(/"/g,'&quot;')+'">'+k+' <i>'+obj[k]+'</i></button>'; });
    el.innerHTML=h;
    el.onclick=function(e){var b=e.target.closest('.chip');if(!b)return;onPick(b.dataset.v);
      [].forEach.call(el.querySelectorAll('.chip'),function(t){t.classList.remove('on');});b.classList.add('on');};
  }
  function renderFilters(){
    var d=CATS[type]||{};
    var catObj=(d&&d.categories)?d.categories:(d||{});   // new: {categories,countries}; old: {cat:count}
    var countryObj=(d&&d.countries)?d.countries:{};
    chips(g('cats'), catObj, cat, false, function(v){cat=v;load(true);});
    var cn=g('countries'); if(Object.keys(countryObj).length){cn.style.display='';chips(cn, countryObj, country, true, function(v){country=v;load(true);});} else {cn.style.display='none';}
  }
  function card(it){
    var qv=it.quality?'<span class="q">'+it.quality.replace(/\\//g,' · ')+'</span>':'';
    var ep=it.episodes?'<span class="ep">'+it.episodes+' eps</span>':'';
    var co=(it.country&&it.country!=='Worldwide')?'<span class="co">'+it.country+'</span>':'';
    return '<div class="card"><div class="nm">'+(it.name||'').replace(/</g,'&lt;')+'</div><div class="tags">'+qv+ep+'<span class="ct">'+(it.category||'')+'</span>'+co+'</div></div>';
  }
  function load(reset){
    if(loading)return;loading=true;if(reset){page=1;grid.innerHTML='';}
    var u=BASE+'/iptv/'+SERVER+'/browse.json?type='+type+'&page='+page+'&size=48'+(cat?'&cat='+encodeURIComponent(cat):'')+(country?'&country='+encodeURIComponent(country):'')+(q?'&q='+encodeURIComponent(q):'');
    fetch(u).then(function(r){return r.json();}).then(function(d){
      loading=false;
      if(!d.ok){grid.innerHTML='<div class="empty">This server is still importing — check back soon.</div>';meta.textContent='';more.style.display='none';return;}
      pages=d.pages;
      if(d.total===0){grid.innerHTML='<div class="empty">No matches.</div>';}
      else{ d.items.forEach(function(it){grid.insertAdjacentHTML('beforeend',card(it));}); }
      meta.textContent=d.total.toLocaleString()+' '+(type==='vod'?'movies':type==='series'?'series':'channels')+(cat?' · '+cat:'')+(country?' · '+country:'')+(q?' · “'+q+'”':'');
      more.style.display=(page<pages)?'block':'none';
    }).catch(function(){loading=false;});
  }
  g('tabs').addEventListener('click',function(e){var b=e.target.closest('.tab');if(!b)return;
    [].forEach.call(document.querySelectorAll('.tab'),function(t){t.classList.remove('on');});b.classList.add('on');
    type=b.dataset.t;cat='';country='';renderFilters();load(true);});
  var qt;g('q').addEventListener('input',function(e){clearTimeout(qt);q=e.target.value.trim();qt=setTimeout(function(){load(true);},250);});
  more.addEventListener('click',function(){page++;load(false);});
  // preload flag map from stored country keys (flags come with items; also seed from a small guess)
  renderFilters();load(true);
</script></body></html>`;
}

function libraryIndexHtml(servers, base) {
  const grand = servers.reduce((a, s) => a + (+s.raw_live || +s.live_count || 0) + (+s.raw_vod || +s.vod_count || 0) + (+s.raw_series || +s.series_count || 0), 0);
  const cards = servers.map(s => {
    const live = +s.raw_live || +s.live_count || 0, vod = +s.raw_vod || +s.vod_count || 0, ser = +s.raw_series || +s.series_count || 0;
    return `<a class="lib" href="/library/${encodeURIComponent(s.server_key)}">
      <div class="lib-nm disp">${esc(s.name || s.server_key)}</div>
      <div class="lib-big disp">${fmt(live + vod + ser)}</div>
      <div class="lib-row"><span>${fmt(live)} live</span><span>${fmt(vod)} movies</span><span>${fmt(ser)} series</span></div>
    </a>`;
  }).join('');
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Live IPTV Library — What's Inside | Galaxy Subz × Zayron</title>
<meta name="description" content="Browse the full live library on every Galaxy Subz × Zayron IPTV server — millions of channels, movies and series by category and country.">
${STYLE}
<style>.libgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px;padding:24px 0 50px}
  .lib{border:1px solid var(--line);border-radius:18px;padding:22px;background:#fff;transition:border-color .15s,transform .15s,box-shadow .15s}
  .lib:hover{border-color:var(--chipbd);transform:translateY(-2px);box-shadow:0 10px 30px rgba(91,61,245,.08)}
  .lib-nm{font-weight:600;font-size:1.08rem}
  .lib-big{font-size:2.1rem;font-weight:700;letter-spacing:-.02em;margin:.3rem 0;background:linear-gradient(135deg,var(--accent),var(--accent2));-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
  .lib-row{display:flex;gap:12px;color:var(--muted);font-size:.86rem;font-weight:500}</style></head><body>
${topbar()}
<section class="hero"><div class="wrap">
  <h1 class="title disp">What's Inside</h1>
  <p class="sub">Browse the full live library across every server — ${fmt(grand)} channels, movies and series, organised by category and country, refreshed automatically.</p>
</div></section>
<main class="wrap"><div class="libgrid">${cards || '<div class="empty">Libraries are importing…</div>'}</div></main>
<footer class="foot"><div class="wrap">Galaxy Subz × Zayron</div></footer></body></html>`;
}

module.exports = { serverExplorerHtml, libraryIndexHtml };
