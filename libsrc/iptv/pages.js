'use strict';
/* IPTV Library Engine — "What's Inside" explorer pages. Premium, light, white. Server-rendered shell
   (counts + category chips embedded for instant paint) + a browse API for search / filter / paging.
   Self-contained HTML (inline CSS/JS). Designed to stand alone at /library and /library/:server and
   to be dropped into a product page later. */

function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function fmt(n) { n = +n || 0; return n >= 1e6 ? (n / 1e6).toFixed(1).replace(/\.0$/, '') + 'M' : n >= 1e3 ? (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'K' : String(n); }

const HEAD = `<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  :root{--ink:#0e1117;--muted:#5b6472;--line:#e9ecf1;--bg:#ffffff;--soft:#f7f8fb;--accent:#5a3df0;--accent2:#8b5cf6;--chip:#f1f0fe;--ok:#0ea06a}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--ink);font-family:Inter,system-ui,sans-serif;-webkit-font-smoothing:antialiased;line-height:1.5}
  a{color:inherit;text-decoration:none}
  .wrap{max-width:1180px;margin:0 auto;padding:0 20px}
  .disp{font-family:'Space Grotesk',Inter,sans-serif}
  /* hero */
  .hero{position:relative;overflow:hidden;border-bottom:1px solid var(--line);background:
     radial-gradient(1200px 400px at 85% -10%,rgba(139,92,246,.10),transparent 60%),
     radial-gradient(900px 360px at 5% -20%,rgba(90,61,240,.08),transparent 60%),#fff}
  .hero .wrap{padding:38px 20px 30px}
  .back{color:var(--muted);font-weight:500;font-size:.9rem}
  .title{font-weight:700;font-size:clamp(1.9rem,4.2vw,3rem);letter-spacing:-.02em;margin:.5rem 0 .1rem}
  .sub{color:var(--muted);max-width:640px}
  .stats{display:flex;flex-wrap:wrap;gap:12px;margin-top:22px}
  .stat{flex:1 1 150px;min-width:140px;border:1px solid var(--line);border-radius:16px;padding:16px 18px;background:#fff}
  .stat b{font-family:'Space Grotesk';display:block;font-size:1.8rem;font-weight:700;letter-spacing:-.02em;line-height:1}
  .stat span{color:var(--muted);font-size:.82rem;font-weight:500;text-transform:uppercase;letter-spacing:.06em}
  .stat.lead{background:linear-gradient(135deg,var(--accent),var(--accent2));border:none;color:#fff}
  .stat.lead span{color:rgba(255,255,255,.85)}
  /* controls */
  .bar{position:sticky;top:0;z-index:5;background:rgba(255,255,255,.88);backdrop-filter:blur(10px);border-bottom:1px solid var(--line)}
  .bar .wrap{display:flex;gap:14px;align-items:center;padding:12px 20px;flex-wrap:wrap}
  .tabs{display:flex;gap:4px;background:var(--soft);border-radius:12px;padding:4px}
  .tab{border:none;background:none;font:600 .92rem Inter;color:var(--muted);padding:8px 16px;border-radius:9px;cursor:pointer}
  .tab.on{background:#fff;color:var(--ink);box-shadow:0 1px 3px rgba(16,17,23,.08)}
  .search{flex:1;min-width:180px;display:flex;align-items:center;gap:8px;border:1px solid var(--line);border-radius:12px;padding:9px 14px;background:#fff}
  .search input{border:none;outline:none;font:500 .95rem Inter;flex:1;background:none;color:var(--ink)}
  .search svg{flex:none;color:var(--muted)}
  .chips{display:flex;gap:8px;overflow-x:auto;padding:14px 0 2px;scrollbar-width:none}
  .chips::-webkit-scrollbar{display:none}
  .chip{white-space:nowrap;border:1px solid var(--line);background:#fff;color:var(--ink);font:600 .84rem Inter;padding:7px 14px;border-radius:999px;cursor:pointer}
  .chip.on{background:var(--chip);border-color:#d8d4fb;color:var(--accent)}
  .chip i{color:var(--muted);font-style:normal;font-weight:500;margin-left:5px}
  /* grid */
  .meta{color:var(--muted);font-size:.9rem;margin:16px 0 6px}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:10px;padding-bottom:30px}
  .card{border:1px solid var(--line);border-radius:13px;padding:13px 15px;background:#fff;display:flex;flex-direction:column;gap:7px;transition:border-color .15s,transform .15s}
  .card:hover{border-color:#d8d4fb;transform:translateY(-1px)}
  .nm{font-weight:600;font-size:.96rem;line-height:1.3;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical}
  .tags{display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin-top:auto}
  .q{font:600 .7rem Inter;color:var(--accent);background:var(--chip);border-radius:6px;padding:2px 7px;letter-spacing:.03em}
  .ct{font:500 .76rem Inter;color:var(--muted)}
  .ep{font:600 .72rem Inter;color:var(--ok);background:#e9f8f1;border-radius:6px;padding:2px 7px}
  .more{display:block;margin:6px auto 40px;border:1px solid var(--line);background:#fff;color:var(--ink);font:600 .95rem Inter;padding:12px 26px;border-radius:12px;cursor:pointer}
  .empty{color:var(--muted);text-align:center;padding:50px 0}
  .foot{border-top:1px solid var(--line);color:var(--muted);font-size:.85rem;padding:22px 0}
  @media(max-width:640px){.stat b{font-size:1.5rem}.grid{grid-template-columns:repeat(auto-fill,minmax:160px,1fr)}}
</style>`;

function serverExplorerHtml(row, base) {
  const cats = row.categories || {};
  const counts = { live: row.live_count, vod: row.vod_count, series: row.series_count };
  const name = esc(row.name || row.server_key);
  const updated = row.updated_at ? new Date(row.updated_at).toISOString().slice(0, 10) : '';
  const total = (+row.live_count || 0) + (+row.vod_count || 0) + (+row.series_count || 0);
  return `<!doctype html><html lang="en"><head><title>${name} — What's Inside</title>
${HEAD}</head><body>
<header class="hero"><div class="wrap">
  <a class="back" href="/library">← All servers</a>
  <h1 class="title disp">${name}</h1>
  <p class="sub">Everything inside this server — live channels, movies and series, cleaned and de-duplicated. Updated ${updated}.</p>
  <div class="stats">
    <div class="stat lead"><b>${fmt(total)}</b><span>Total titles</span></div>
    <div class="stat"><b>${fmt(row.live_count)}</b><span>Live TV</span></div>
    <div class="stat"><b>${fmt(row.vod_count)}</b><span>Movies</span></div>
    <div class="stat"><b>${fmt(row.series_count)}</b><span>Series</span></div>
    <div class="stat"><b>${fmt(row.episode_count)}</b><span>Episodes</span></div>
  </div>
</div></header>
<div class="bar"><div class="wrap">
  <div class="tabs" id="tabs">
    <button class="tab on" data-t="live">Live TV</button>
    <button class="tab" data-t="vod">Movies</button>
    <button class="tab" data-t="series">Series</button>
  </div>
  <label class="search"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
    <input id="q" placeholder="Search titles…" autocomplete="off"></label>
</div></div>
<main class="wrap">
  <div class="chips" id="chips"></div>
  <div class="meta" id="meta"></div>
  <div class="grid" id="grid"></div>
  <button class="more" id="more" style="display:none">Show more</button>
</main>
<footer class="foot"><div class="wrap">Galaxy Subz × Zayron — live library, refreshed automatically.</div></footer>
<script>
  var SERVER=${JSON.stringify(row.server_key)}, BASE=${JSON.stringify(base || '')};
  var CATS=${JSON.stringify(cats)}, COUNTS=${JSON.stringify(counts)};
  var type='live', cat='', q='', page=1, pages=1, loading=false;
  var grid=document.getElementById('grid'), meta=document.getElementById('meta'), more=document.getElementById('more'), chipsEl=document.getElementById('chips');
  function renderChips(){
    var c=CATS[type]||{}, keys=Object.keys(c).sort(function(a,b){return c[b]-c[a]});
    var h='<button class="chip '+(cat===''?'on':'')+'" data-c="">All</button>';
    keys.forEach(function(k){ h+='<button class="chip '+(cat===k?'on':'')+'" data-c="'+k.replace(/"/g,'&quot;')+'">'+k+' <i>'+c[k]+'</i></button>'; });
    chipsEl.innerHTML=h;
  }
  function card(it){
    var q=it.quality?'<span class="q">'+it.quality.replace(/\\//g,' · ')+'</span>':'';
    var ep=it.episodes?'<span class="ep">'+it.episodes+' eps</span>':'';
    var v=it.variants>1?'<span class="ct">'+it.variants+' sources</span>':'';
    return '<div class="card"><div class="nm">'+(it.name||'').replace(/</g,'&lt;')+'</div><div class="tags">'+q+ep+v+'<span class="ct">'+(it.category||'')+'</span></div></div>';
  }
  function load(reset){
    if(loading) return; loading=true;
    if(reset){page=1; grid.innerHTML='';}
    var u=BASE+'/iptv/'+SERVER+'/browse.json?type='+type+'&page='+page+'&size=48'+(cat?'&cat='+encodeURIComponent(cat):'')+(q?'&q='+encodeURIComponent(q):'');
    fetch(u).then(function(r){return r.json();}).then(function(d){
      loading=false;
      if(!d.ok){grid.innerHTML='<div class="empty">This server is still importing — check back soon.</div>';meta.textContent='';more.style.display='none';return;}
      pages=d.pages;
      if(d.total===0){grid.innerHTML='<div class="empty">No matches.</div>';}
      else { d.items.forEach(function(it){grid.insertAdjacentHTML('beforeend',card(it));}); }
      meta.textContent=d.total.toLocaleString()+' '+(type==='vod'?'movies':type==='series'?'series':'channels')+(cat?' in '+cat:'')+(q?' matching “'+q+'”':'');
      more.style.display=(page<pages)?'block':'none';
    }).catch(function(){loading=false;});
  }
  document.getElementById('tabs').addEventListener('click',function(e){var b=e.target.closest('.tab');if(!b)return;
    document.querySelectorAll('.tab').forEach(function(t){t.classList.remove('on');});b.classList.add('on');
    type=b.dataset.t;cat='';renderChips();load(true);});
  chipsEl.addEventListener('click',function(e){var b=e.target.closest('.chip');if(!b)return;cat=b.dataset.c;
    document.querySelectorAll('.chip').forEach(function(t){t.classList.remove('on');});b.classList.add('on');load(true);});
  var qt;document.getElementById('q').addEventListener('input',function(e){clearTimeout(qt);q=e.target.value.trim();qt=setTimeout(function(){load(true);},250);});
  more.addEventListener('click',function(){page++;load(false);});
  renderChips();load(true);
</script></body></html>`;
}

function libraryIndexHtml(servers, base) {
  const cards = servers.map(s => {
    const total = (+s.live_count || 0) + (+s.vod_count || 0) + (+s.series_count || 0);
    return `<a class="lib" href="/library/${encodeURIComponent(s.server_key)}">
      <div class="lib-nm disp">${esc(s.name || s.server_key)}</div>
      <div class="lib-big disp">${fmt(total)}</div>
      <div class="lib-row"><span>${fmt(s.live_count)} live</span><span>${fmt(s.vod_count)} movies</span><span>${fmt(s.series_count)} series</span></div>
    </a>`;
  }).join('');
  return `<!doctype html><html lang="en"><head><title>Live IPTV Library — What's Inside</title>${HEAD}
<style>.libgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px;padding:26px 0 50px}
  .lib{border:1px solid var(--line);border-radius:18px;padding:22px;background:#fff;transition:border-color .15s,transform .15s}
  .lib:hover{border-color:#d8d4fb;transform:translateY(-2px)}
  .lib-nm{font-weight:600;font-size:1.1rem}.lib-big{font-size:2.2rem;font-weight:700;letter-spacing:-.02em;margin:.3rem 0;background:linear-gradient(135deg,var(--accent),var(--accent2));-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
  .lib-row{display:flex;gap:12px;color:var(--muted);font-size:.86rem;font-weight:500}</style></head><body>
<header class="hero"><div class="wrap">
  <h1 class="title disp">What's Inside</h1>
  <p class="sub">Browse the full live library on every server — channels, movies and series, updated automatically.</p>
</div></header>
<main class="wrap"><div class="libgrid">${cards || '<div class="empty">Libraries are importing…</div>'}</div></main>
<footer class="foot"><div class="wrap">Galaxy Subz × Zayron</div></footer></body></html>`;
}

module.exports = { serverExplorerHtml, libraryIndexHtml };
