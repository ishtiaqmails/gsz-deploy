#!/usr/bin/env bash
# stepMaintFit.sh — crop the logo's baked-in transparent padding via a clip box so it sits tight to the content.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
cp -f views/maintenance.ejs "views/maintenance.ejs.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "views/maintenance.ejs.xbak.$TS" views/maintenance.ejs; rm -f .gszm_v.js; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> updating view"
cat > views/maintenance.ejs <<'GSZM_PUB'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="robots" content="noindex">
<title><%= statusText %> — Galaxy Subz × Zayron</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Sora:wght@400;500;600;700;800&family=Inter:wght@400;500;600&display=swap">
<style>
:root{--bg:#070912;--ink:#eef1ff;--muted:#8b93bb;--faint:#5b6186;--line:rgba(255,255,255,.09);--card:rgba(255,255,255,.04);
  --v:#8b45ff;--b:#3b82ff;--c:#28d6ff;--brand:linear-gradient(100deg,#8b45ff,#3b82ff 55%,#28d6ff);
  --glow:0 10px 40px rgba(59,130,255,.35);--disp:'Sora',system-ui,sans-serif;--body:'Inter',system-ui,-apple-system,sans-serif;color-scheme:dark}
*{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%}
body{background:var(--bg);color:var(--ink);font-family:var(--body);min-height:100svh;display:flex;align-items:center;justify-content:center;overflow:hidden;position:relative;padding:max(22px,env(safe-area-inset-left)) max(22px,env(safe-area-inset-right))}
#sky{position:fixed;inset:0;z-index:0;display:block}
.nebula{position:fixed;z-index:0;border-radius:50%;filter:blur(90px);opacity:.5;pointer-events:none}
.n1{width:60vmax;height:60vmax;left:-20vmax;top:-25vmax;background:radial-gradient(circle,rgba(139,69,255,.55),transparent 65%)}
.n2{width:55vmax;height:55vmax;right:-22vmax;bottom:-25vmax;background:radial-gradient(circle,rgba(40,214,255,.4),transparent 65%)}
.vignette{position:fixed;inset:0;z-index:1;pointer-events:none;background:radial-gradient(120% 90% at 50% 40%,transparent 55%,rgba(5,6,14,.85) 100%)}
.stage{position:relative;z-index:2;width:100%;max-width:720px;text-align:center;display:flex;flex-direction:column;align-items:center;gap:clamp(16px,2.6vh,30px)}
.brandwrap{position:relative;display:flex;align-items:center;justify-content:center;width:min(470px,88vw);max-width:100%;aspect-ratio:958/406;overflow:hidden}
.logo{width:100%;height:auto;display:block}
.chip{display:inline-flex;align-items:center;gap:.5rem;background:var(--card);border:1px solid var(--line);border-radius:999px;padding:.42rem .95rem;font-size:.8rem;font-weight:600;color:var(--ink);letter-spacing:.02em}
.chip .dot{width:8px;height:8px;border-radius:50%;background:#ffd35c;box-shadow:0 0 10px #ffd35c;animation:pulse 1.6s infinite}
h1{font-family:var(--disp);font-weight:800;line-height:1.05;letter-spacing:-.02em;font-size:clamp(2rem,6.4vw,3.6rem)}
.lead{color:var(--muted);font-size:clamp(1rem,2.4vw,1.15rem);max-width:46ch;line-height:1.6}
.count{display:flex;gap:clamp(8px,2vw,16px);justify-content:center}
.unit{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:clamp(12px,2vh,18px) clamp(10px,2.4vw,22px);min-width:clamp(62px,17vw,92px);backdrop-filter:blur(8px)}
.unit .num{font-family:var(--disp);font-weight:800;font-size:clamp(1.7rem,6vw,2.8rem);line-height:1;font-variant-numeric:tabular-nums;background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent}
.unit .lbl{margin-top:.5rem;font-size:.72rem;letter-spacing:.14em;text-transform:uppercase;color:var(--faint)}
.eta{font-size:.9rem;color:var(--muted)}
.eta b{color:var(--ink);font-weight:600}
.contact{display:flex;flex-wrap:wrap;gap:10px;justify-content:center;margin-top:2px}
.contact .btn{display:inline-flex;align-items:center;gap:.5rem;border-radius:999px;padding:.6rem 1.15rem;font-size:.92rem;font-weight:600;border:1px solid var(--line);background:var(--card);color:var(--ink);cursor:pointer;transition:.16s;text-decoration:none}
.contact .btn:hover{border-color:rgba(255,255,255,.28);transform:translateY(-2px)}
.contact .btn.g{background:var(--brand);border-color:transparent;box-shadow:var(--glow)}
.foot{position:fixed;left:0;right:0;bottom:max(14px,env(safe-area-inset-bottom));z-index:2;text-align:center;color:var(--faint);font-size:.78rem}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.35}}
@media (prefers-reduced-motion:reduce){.chip .dot{animation:none}}
@media (max-height:640px){.brandwrap{width:min(380px,80vw)}}
</style>
</head>
<body>
<canvas id="sky"></canvas>
<div class="nebula n1"></div>
<div class="nebula n2"></div>
<div class="vignette"></div>
<main class="stage">
  <div class="brandwrap"><img class="logo" src="<%= logo %>" alt="Galaxy Subz × Zayron" onerror="this.style.display='none'"></div>
  <span class="chip"><span class="dot"></span> <%= statusText %></span>
  <h1><%= title %></h1>
  <p class="lead"><%= message %></p>
  <% if (endTime) { %>
  <div class="count" id="count" aria-live="polite">
    <div class="unit"><div class="num" id="d">00</div><div class="lbl">Days</div></div>
    <div class="unit"><div class="num" id="h">00</div><div class="lbl">Hours</div></div>
    <div class="unit"><div class="num" id="m">00</div><div class="lbl">Minutes</div></div>
    <div class="unit"><div class="num" id="s">00</div><div class="lbl">Seconds</div></div>
  </div>
  <p class="eta" id="eta"></p>
  <% } %>
  <div class="contact">
    <a class="btn g" id="waBtn" href="#" target="_blank" rel="noopener" style="display:none"><svg viewBox="0 0 24 24" width="19" height="19" fill="currentColor" aria-hidden="true"><path d="M19.05 4.91A9.82 9.82 0 0 0 12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2 22l5.25-1.38a9.9 9.9 0 0 0 4.79 1.22h.004c5.46 0 9.91-4.45 9.91-9.91 0-2.65-1.03-5.14-2.9-7.02zm-7.01 15.24h-.003a8.23 8.23 0 0 1-4.19-1.15l-.3-.18-3.12.82.83-3.04-.2-.31a8.2 8.2 0 0 1-1.26-4.39c0-4.54 3.7-8.23 8.24-8.23a8.2 8.2 0 0 1 5.82 2.41 8.18 8.18 0 0 1 2.41 5.83c0 4.54-3.7 8.24-8.24 8.24zm4.52-6.16c-.25-.12-1.47-.72-1.69-.81-.23-.08-.39-.12-.56.12-.17.25-.64.81-.79.97-.14.17-.29.19-.54.06-.25-.12-1.05-.39-1.99-1.23-.74-.66-1.23-1.47-1.38-1.72-.14-.25-.02-.38.11-.5.11-.11.25-.29.37-.43.12-.14.17-.25.25-.41.08-.17.04-.31-.02-.43-.06-.12-.56-1.34-.76-1.84-.2-.48-.41-.42-.56-.43h-.48c-.17 0-.43.06-.66.31-.23.25-.86.85-.86 2.07 0 1.22.89 2.4 1.01 2.56.12.17 1.75 2.67 4.23 3.74.59.26 1.05.41 1.41.52.59.19 1.13.16 1.56.1.48-.07 1.47-.6 1.68-1.18.21-.58.21-1.07.14-1.18-.06-.1-.22-.16-.47-.28z"/></svg> Contact us on WhatsApp</a>
  </div>
</main>
<div class="foot">© <span id="yr"></span> Galaxy Subz × Zayron</div>
<script>
var CONFIG = {
  endTime: <%- JSON.stringify(endTime || '') %>,
  whatsapp: <%- JSON.stringify(whatsapp || '') %>
};
document.getElementById('yr').textContent = new Date().getFullYear();
var wa = document.getElementById('waBtn');
if (CONFIG.whatsapp) { wa.href = 'https://wa.me/' + CONFIG.whatsapp; wa.style.display = 'inline-flex'; }
if (CONFIG.endTime) {
  var end = new Date(CONFIG.endTime).getTime();
  var eta = document.getElementById('eta');
  try { eta.innerHTML = 'Expected back by <b>' + new Date(end).toLocaleString(undefined, { weekday: 'short', hour: '2-digit', minute: '2-digit', day: 'numeric', month: 'short' }) + '</b>'; } catch (e) {}
  var pad = function (n) { return (n < 10 ? '0' : '') + n; };
  var timer = setInterval(tick, 1000);
  function tick() {
    var diff = end - Date.now();
    if (isNaN(diff) || diff <= 0) {
      var cEl = document.getElementById('count');
      if (cEl) cEl.innerHTML = "<div class='unit' style='min-width:auto'><div class='num'>Soon</div><div class='lbl'>Back online</div></div>";
      if (eta) eta.textContent = "We're back any moment — please refresh.";
      clearInterval(timer); return;
    }
    var s = Math.floor(diff / 1000);
    document.getElementById('d').textContent = pad(Math.floor(s / 86400));
    document.getElementById('h').textContent = pad(Math.floor(s % 86400 / 3600));
    document.getElementById('m').textContent = pad(Math.floor(s % 3600 / 60));
    document.getElementById('s').textContent = pad(s % 60);
  }
  tick();
}
(function () {
  var c = document.getElementById('sky'), x = c.getContext('2d'), w, h, stars, dpr;
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  function initS() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    w = c.width = innerWidth * dpr; h = c.height = innerHeight * dpr;
    c.style.width = innerWidth + 'px'; c.style.height = innerHeight + 'px';
    var n = Math.min(160, Math.floor(innerWidth * innerHeight / 9000));
    stars = [];
    for (var i = 0; i < n; i++) stars.push({ x: Math.random() * w, y: Math.random() * h, r: (Math.random() * 1.3 + 0.3) * dpr, a: Math.random(), sp: Math.random() * 0.02 + 0.004, vy: (Math.random() * 0.12 + 0.02) * dpr });
  }
  function draw() {
    x.clearRect(0, 0, w, h);
    for (var i = 0; i < stars.length; i++) {
      var st = stars[i];
      st.a += st.sp; var tw = 0.5 + Math.abs(Math.sin(st.a)) * 0.5;
      if (!reduce) { st.y += st.vy; if (st.y > h) st.y = 0; }
      x.globalAlpha = tw; x.fillStyle = '#dfe6ff';
      x.beginPath(); x.arc(st.x, st.y, st.r, 0, 6.283); x.fill();
    }
    x.globalAlpha = 1;
    if (!reduce) requestAnimationFrame(draw);
  }
  initS(); draw();
  addEventListener('resize', function () { initS(); if (reduce) draw(); });
})();
</script>
</body>
</html>
GSZM_PUB
echo "==> validating"
cat > .gszm_v.js <<'GSZM_V'
const ejs=require('ejs'),fs=require('fs');
const pub=ejs.render(fs.readFileSync('views/maintenance.ejs','utf8'),{logo:'/static/img/maint-logo.png',statusText:'s',title:'t',message:'m',endTime:'2026-11-02T22:00',whatsapp:'923001234567'},{filename:'views/maintenance.ejs'});
const m=pub.match(/<script>([\s\S]*?)<\/script>/); if(!m) throw new Error('no script'); fs.writeFileSync('/tmp/gszm_script.js',m[1]);
console.log('  view renders');
GSZM_V
node .gszm_v.js
node --check /tmp/gszm_script.js
rm -f .gszm_v.js
echo "   checks passed"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed"; false; }
trap - ERR
echo "DONE — logo padding cropped; logo now sits tight to the content."
