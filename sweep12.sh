#!/usr/bin/env bash
# gsz-sweep12 : IPTV product cards show Live/Movies/Series counts as a compact
# overlay strip on the card image (card size unchanged). IPTV cards are marked
# .is-iptv server-side so only they fetch; fills are lazy (IntersectionObserver)
# and cached (sessionStorage) so no request storm.
set -e
cd /opt/gsz
J=public/js/app.js
A=public/css/app.css
H=views/home.ejs
C=views/category.ejs

if grep -q 'gsz-iptv-card-counts' "$J"; then echo "sweep12 already applied"; exit 0; fi

cp "$J" /opt/gsz/.gsz-s12-appjs.bak
cp "$A" /opt/gsz/.gsz-s12-appcss.bak
cp "$H" /opt/gsz/.gsz-s12-home.bak
cp "$C" /opt/gsz/.gsz-s12-cat.bak

# 1) mark IPTV product cards with .is-iptv (home + category card builders)
cat > /tmp/s12edit.js <<'JS'
const fs=require('fs');
function repl(f,a,b){let s=fs.readFileSync(f,'utf8');const n=s.split(a).length-1;if(n!==1){console.error('EXPECT 1 MATCH in '+f+', got '+n);process.exit(3);}fs.writeFileSync(f,s.replace(a,b));}
const A='return \'<a class="pcard" href="/product/\'';
const B='return \'<a class="pcard\'+(p.cat===\'iptv\'?\' is-iptv\':\'\')+\'" href="/product/\'';
repl('views/home.ejs',A,B);
repl('views/category.ejs',A,B);
console.log('marked iptv cards');
JS
node /tmp/s12edit.js || { echo "marker edit failed — reverting"; cp /opt/gsz/.gsz-s12-home.bak "$H"; cp /opt/gsz/.gsz-s12-cat.bak "$C"; exit 1; }

# 2) overlay CSS
cat >> "$A" <<'CSS'

/* gsz-iptv-card-counts : Live/Movies/Series overlay on IPTV product cards */
.pcard .pmedia{position:relative;overflow:hidden;display:block;line-height:0}
.pc-counts{position:absolute;left:0;right:0;bottom:0;z-index:2;display:flex;pointer-events:none;line-height:1;padding:8px 6px 7px;gap:0;background:linear-gradient(180deg,rgba(6,10,20,0),rgba(6,10,20,.84) 60%)}
.pc-counts i{flex:1;min-width:0;display:flex;flex-direction:column;align-items:center;text-align:center}
.pc-counts i+i{border-left:1px solid rgba(255,255,255,.16)}
.pc-counts i b{font-family:var(--display);font-weight:800;font-size:13px;color:#fff;font-variant-numeric:tabular-nums}
.pc-counts i span{font-size:8px;font-weight:700;letter-spacing:.06em;color:#c6d0ea;margin-top:2px}
CSS

# 3) lazy + cached fill script
cat >> "$J" <<'JS'

/* gsz-iptv-card-counts : show Live/Movies/Series on IPTV product cards (lazy + cached) */
(function(){
  var cards=[].slice.call(document.querySelectorAll('a.pcard.is-iptv[href^="/product/"]'));
  if(!cards.length) return;
  var cache={}; try{cache=JSON.parse(sessionStorage.getItem('gsz_ic')||'{}')||{}}catch(e){}
  function save(){try{sessionStorage.setItem('gsz_ic',JSON.stringify(cache))}catch(e){}}
  function fmt(n){n=+n||0;if(n>=1000){var k=n/1000;return (k>=100?Math.round(k):Math.round(k*10)/10)+'K';}return String(n);}
  function paint(card,v){
    if(!v||!(v.l||v.v||v.s))return;
    var img=card.querySelector('.pimg,.pfallback');if(!img||card.querySelector('.pc-counts'))return;
    var media=document.createElement('div');media.className='pmedia';
    img.parentNode.insertBefore(media,img);media.appendChild(img);
    var el=document.createElement('div');el.className='pc-counts';
    el.innerHTML='<i><b>'+fmt(v.l)+'</b><span>LIVE</span></i><i><b>'+fmt(v.v)+'</b><span>MOVIES</span></i><i><b>'+fmt(v.s)+'</b><span>SERIES</span></i>';
    media.appendChild(el);
  }
  function load(card){
    var m=(card.getAttribute('href')||'').match(/\/product\/([^/?#]+)/);if(!m)return;var slug=m[1];
    if(cache[slug]!==undefined){if(cache[slug])paint(card,cache[slug]);return;}
    fetch('/iptv/'+encodeURIComponent(slug)+'/summary.json',{headers:{'X-Requested-With':'fetch'},credentials:'same-origin'})
      .then(function(r){return r.ok?r.json():null;})
      .then(function(j){
        var v=0;
        if(j&&j.ok&&j.server){var s=j.server;
          var l=(+s.raw_live>0?+s.raw_live:+s.live_count)||0,vv=(+s.raw_vod>0?+s.raw_vod:+s.vod_count)||0,se=(+s.raw_series>0?+s.raw_series:+s.series_count)||0;
          if(l||vv||se)v={l:l,v:vv,s:se};
        }
        cache[slug]=v;save();if(v)paint(card,v);
      }).catch(function(){});
  }
  if('IntersectionObserver' in window){
    var io=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){io.unobserve(e.target);load(e.target);}});},{rootMargin:'250px'});
    cards.forEach(function(c){io.observe(c);});
  } else cards.forEach(load);
})();
JS

# 4) validate
if ! node --check "$J" 2>/tmp/jserr; then echo "app.js syntax error — reverting:"; cat /tmp/jserr; cp /opt/gsz/.gsz-s12-appjs.bak "$J"; cp /opt/gsz/.gsz-s12-appcss.bak "$A"; cp /opt/gsz/.gsz-s12-home.bak "$H"; cp /opt/gsz/.gsz-s12-cat.bak "$C"; exit 1; fi
for f in "$H" "$C"; do
  if ! node -e "require('ejs').compile(require('fs').readFileSync('$f','utf8'),{filename:'$f'})" 2>/tmp/ejserr; then echo "EJS FAILED $f — reverting:"; cat /tmp/ejserr; cp /opt/gsz/.gsz-s12-appjs.bak "$J"; cp /opt/gsz/.gsz-s12-appcss.bak "$A"; cp /opt/gsz/.gsz-s12-home.bak "$H"; cp /opt/gsz/.gsz-s12-cat.bak "$C"; exit 1; fi
done

# 5) cache-bust app.css (app.js auto-busts via assetVer)
NV=$(date +%s)
for F in $(grep -rlE 'app\.css\?v=' views --include=*.ejs 2>/dev/null); do sed -i -E "s#(app\.css\?v=)[0-9]+#\1$NV#g" "$F"; done

pm2 restart gsz
echo "DONE: IPTV product cards now show Live/Movies/Series counts"
