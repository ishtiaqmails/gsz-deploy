#!/usr/bin/env bash
# Feature B+C v2: compact, dark-themed version of the IPTV product-page strip.
# Restores product.ejs to clean backup, then applies a slim counts bar + one-line reco.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
BK=$(ls -t views/product.ejs.bak.* 2>/dev/null | head -1)
if [ -z "$BK" ]; then echo "NO BACKUP FOUND - aborting"; exit 1; fi
cp "$BK" views/product.ejs
echo "restored clean product.ejs from $BK"
if grep -q "iptv-quick" views/product.ejs; then echo "backup still contains injection - aborting, tell Claude"; exit 1; fi
ts=$(date +%s); cp views/product.ejs "views/product.ejs.clean.$ts"
restore(){ echo "ROLLING BACK"; cp "$BK" views/product.ejs; }

node <<'NODE'
const fs=require('fs');
function P(file,pairs){ let s=fs.readFileSync(file,'utf8'); for(const [a,b] of pairs){ const n=s.split(a).length-1; if(n!==1){ console.log('FAIL anchor x'+n+' ['+file+']: '+JSON.stringify(a.slice(0,70))); process.exit(1);} s=s.split(a).join(b);} fs.writeFileSync(file,s); console.log('patched '+file); }

const css=`  .iptv-quick{margin:14px 0 2px}
  .iq-bar{display:flex;align-items:center;gap:12px;flex-wrap:wrap;width:100%;padding:11px 14px;border:1px solid rgba(255,255,255,.1);border-radius:12px;background:rgba(255,255,255,.04);color:#fff;cursor:pointer;text-align:left;transition:background .15s,border-color .15s}
  .iq-bar:hover{background:rgba(255,255,255,.08);border-color:rgba(255,255,255,.2)}
  .iq-stat{font-size:12.5px;color:#aeb7c7;font-weight:600;white-space:nowrap}
  .iq-stat b{font-size:16px;font-weight:800;color:#fff;margin-right:4px}
  .iq-sep{width:1px;height:20px;background:rgba(255,255,255,.14)}
  .iq-go{margin-left:auto;display:inline-flex;align-items:center;gap:5px;font-size:12.5px;font-weight:700;color:#8fb4ff;white-space:nowrap}
  .iq-go svg{width:14px;height:14px;fill:none;stroke:currentColor;stroke-width:2.2}
  .iq-reco{display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-top:9px;font-size:12px}
  .iq-reco-lab{color:#8b94a7;font-weight:700}
  .iq-rg{display:inline-flex;align-items:center;gap:5px}
  .iq-rg i{color:#8b94a7;font-style:normal;font-weight:700;font-size:11px}
  .iq-rg em{font-style:normal;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.12);border-radius:999px;padding:2px 8px;font-size:11px;color:#e6ebf5}
  @media(max-width:520px){.iq-sep{display:none}.iq-go{margin-left:0}}
`;

const strip=`<% if (p.cat_slug==='iptv') { %>
      <div class="iptv-quick" id="iptvQuick" data-slug="<%= p.slug %>" hidden>
        <button type="button" class="iq-bar" data-go="library">
          <span class="iq-stat"><b id="iqLive">-</b>Live TV</span>
          <span class="iq-sep"></span>
          <span class="iq-stat"><b id="iqVod">-</b>Movies</span>
          <span class="iq-sep"></span>
          <span class="iq-stat"><b id="iqSeries">-</b>Series</span>
          <span class="iq-go">What's inside <svg viewBox="0 0 24 24"><path d="M5 12h14"/><path d="M13 6l6 6-6 6"/></svg></span>
        </button>
        <div class="iq-reco" id="iqReco"></div>
      </div>
      <script>
      (function(){
        var box=document.getElementById('iptvQuick'); if(!box) return;
        var slug=box.getAttribute('data-slug');
        function fmt(n){return Number(n||0).toLocaleString('en-US');}
        function esc(t){var d=document.createElement('div');d.textContent=(t==null?'':String(t));return d.innerHTML;}
        function topc(o){ if(!o) return []; return Object.keys(o).filter(function(c){return c&&c!=='Worldwide'&&c!=='Unknown';}).sort(function(a,b){return o[b]-o[a];}).slice(0,2); }
        function go(){ var t=document.querySelector('.ptab[data-tab="library"]'); if(t){ t.click(); } var p=document.getElementById('wiPanel'); if(p){ setTimeout(function(){ p.scrollIntoView({behavior:'smooth',block:'start'}); },60); } }
        [].slice.call(box.querySelectorAll('[data-go="library"]')).forEach(function(b){ b.addEventListener('click',go); });
        fetch('/iptv/'+encodeURIComponent(slug)+'/summary.json',{headers:{'X-Requested-With':'fetch'},credentials:'same-origin'}).then(function(r){return r.json();}).then(function(j){
          if(!j||!j.ok||!j.server) return; var s=j.server;
          if(!((+s.live_count)||(+s.vod_count)||(+s.series_count))) return;
          document.getElementById('iqLive').textContent=fmt(s.live_count);
          document.getElementById('iqVod').textContent=fmt(s.vod_count);
          document.getElementById('iqSeries').textContent=fmt(s.series_count);
          var c=s.categories||{};
          var defs=[['Live',(c.live||{}).countries],['Movies',(c.vod||{}).countries],['Series',(c.series||{}).countries]];
          var groups='';
          defs.forEach(function(d){ var tc=topc(d[1]); if(tc.length){ groups+='<span class="iq-rg"><i>'+d[0]+'</i>'+tc.map(function(x){return '<em>'+esc(x)+'</em>';}).join('')+'</span>'; } });
          if(groups){ document.getElementById('iqReco').innerHTML='<span class="iq-reco-lab">Best for</span>'+groups; }
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
