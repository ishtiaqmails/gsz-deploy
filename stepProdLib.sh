#!/usr/bin/env bash
# Feature B+C: IPTV product page — content counts (Live/Movies/Series) + per-type
# country recommendations near the plans, tapping jumps to "What's Inside". product.ejs only.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
ts=$(date +%s)
cp views/product.ejs "views/product.ejs.bak.$ts"
restore(){ echo "ROLLING BACK"; cp "views/product.ejs.bak.$ts" views/product.ejs; }

node <<'NODE'
const fs=require('fs');
function P(file,pairs){ let s=fs.readFileSync(file,'utf8'); for(const [a,b] of pairs){ const n=s.split(a).length-1; if(n!==1){ console.log('FAIL anchor x'+n+' ['+file+']: '+JSON.stringify(a.slice(0,70))); process.exit(1);} s=s.split(a).join(b);} fs.writeFileSync(file,s); console.log('patched '+file); }

const css=`  .iptv-quick{margin:14px 0 2px;padding:14px;border:1px solid var(--hair,#e8ecf3);border-radius:14px;background:#fff}
  .iq-counts{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px}
  .iq-chip{display:flex;flex-direction:column;align-items:center;gap:3px;padding:11px 6px;border:1px solid var(--hair,#e8ecf3);border-radius:12px;background:#f7f9fc;cursor:pointer;transition:background .15s,border-color .15s}
  .iq-chip:hover{background:#eef3fb;border-color:#cfd9ea}
  .iq-chip b{font-size:19px;font-weight:800;color:#0f1836;line-height:1}
  .iq-chip span{font-size:11.5px;color:#5a6782;font-weight:600}
  .iq-reco{margin-top:11px}
  .iq-reco-head{font-size:12px;font-weight:800;color:#0f1836;margin-bottom:6px}
  .iq-reco-row{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:5px}
  .iq-reco-lab{font-size:12px;color:#5a6782;font-weight:700;min-width:58px}
  .iq-reco-flags{display:flex;gap:5px;flex-wrap:wrap}
  .iq-flag{font-size:11.5px;color:#22314d;background:#f0f4fa;border:1px solid #e3e9f2;border-radius:999px;padding:2px 9px;font-weight:600}
  .iq-see{display:inline-flex;align-items:center;gap:6px;margin-top:12px;padding:9px 15px;border:0;border-radius:10px;background:#0f1836;color:#fff;font-weight:700;font-size:13px;cursor:pointer}
  .iq-see svg{width:15px;height:15px;fill:none;stroke:currentColor;stroke-width:2.2}
  @media(max-width:520px){.iq-chip b{font-size:17px}}
`;

const strip=`<% if (p.cat_slug==='iptv') { %>
      <div class="iptv-quick" id="iptvQuick" data-slug="<%= p.slug %>" hidden>
        <div class="iq-counts">
          <button type="button" class="iq-chip" data-go="library"><b id="iqLive">-</b><span>Live TV</span></button>
          <button type="button" class="iq-chip" data-go="library"><b id="iqVod">-</b><span>Movies</span></button>
          <button type="button" class="iq-chip" data-go="library"><b id="iqSeries">-</b><span>Series</span></button>
        </div>
        <div class="iq-reco" id="iqReco"></div>
        <button type="button" class="iq-see" data-go="library">See everything inside <svg viewBox="0 0 24 24"><path d="M5 12h14"/><path d="M13 6l6 6-6 6"/></svg></button>
      </div>
      <script>
      (function(){
        var box=document.getElementById('iptvQuick'); if(!box) return;
        var slug=box.getAttribute('data-slug');
        function fmt(n){return Number(n||0).toLocaleString('en-US');}
        function esc(t){var d=document.createElement('div');d.textContent=(t==null?'':String(t));return d.innerHTML;}
        function topc(o){ if(!o) return []; return Object.keys(o).filter(function(c){return c&&c!=='Worldwide'&&c!=='Unknown';}).sort(function(a,b){return o[b]-o[a];}).slice(0,3); }
        function go(){ var t=document.querySelector('.ptab[data-tab="library"]'); if(t){ t.click(); } var p=document.getElementById('wiPanel'); if(p){ setTimeout(function(){ p.scrollIntoView({behavior:'smooth',block:'start'}); },60); } }
        [].slice.call(box.querySelectorAll('[data-go="library"]')).forEach(function(b){ b.addEventListener('click',go); });
        fetch('/iptv/'+encodeURIComponent(slug)+'/summary.json',{headers:{'X-Requested-With':'fetch'},credentials:'same-origin'}).then(function(r){return r.json();}).then(function(j){
          if(!j||!j.ok||!j.server) return; var s=j.server;
          if(!((+s.live_count)||(+s.vod_count)||(+s.series_count))) return;
          document.getElementById('iqLive').textContent=fmt(s.live_count);
          document.getElementById('iqVod').textContent=fmt(s.vod_count);
          document.getElementById('iqSeries').textContent=fmt(s.series_count);
          var c=s.categories||{};
          var rows=[['Live TV',(c.live||{}).countries],['Movies',(c.vod||{}).countries],['Series',(c.series||{}).countries]];
          var html='';
          rows.forEach(function(r){ var tc=topc(r[1]); if(tc.length){ html+='<div class="iq-reco-row"><span class="iq-reco-lab">'+r[0]+'</span><span class="iq-reco-flags">'+tc.map(function(x){return '<span class="iq-flag">'+esc(x)+'</span>';}).join('')+'</span></div>'; } });
          if(html){ document.getElementById('iqReco').innerHTML='<div class="iq-reco-head">Best for</div>'+html; }
          box.hidden=false;
        }).catch(function(){});
      })();
      </script>
      <% } %>
      `;

P('views/product.ejs',[
[`  .ppill-price{display:flex;align-items:baseline;gap:7px;flex-wrap:wrap}`,
 css + `  .ppill-price{display:flex;align-items:baseline;gap:7px;flex-wrap:wrap}`],
[`<!-- version chooser (Family / Adult etc.)`,
 strip + `<!-- version chooser (Family / Adult etc.)`]
]);
NODE
if [ $? -ne 0 ]; then restore; exit 1; fi

echo "== EJS syntax =="
node -e "const ejs=require('/opt/gsz/node_modules/ejs');const fs=require('fs');try{ejs.compile(fs.readFileSync('views/product.ejs','utf8'),{filename:'views/product.ejs',includer:()=>({template:''})});console.log('EJS OK');}catch(e){console.log('EJS FAIL',e.message);process.exit(2);}" || { restore; exit 1; }

echo "== restart =="
pm2 restart gsz --update-env
sleep 2
pm2 list | grep -iE "gsz "
echo DONE
