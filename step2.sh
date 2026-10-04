#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 2: homepage rendered from the DB
#  RUN ON: RETAIL VPS  143.198.209.68  (the galaxytools.net box)
#  Touches ONLY /opt/gsz and the pm2 'gsz' process. No bot restarts.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP" ] || { echo "ABORT: $APP not found — run Step 1 first."; exit 1; }
[ -f "$APP/.env" ] || { echo "ABORT: $APP/.env missing."; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}" "${DB_NAME:?}"
echo "== Galaxy Subz x Zayron — Step 2 · port $PORT =="
mkdir -p "$APP/views" "$APP/public/css" "$APP/public/js" "$APP/public/img"
cp -a "$APP/server.js" "$APP/server.js.bak-step2.$(date +%s)"
cat > "$APP/views/home.ejs" <<'GSZ_EJS_EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title><%= siteName %></title>
<link rel="icon" href="/static/img/logo.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Schibsted+Grotesk:wght@400;500;600;700;800&family=Hanken+Grotesk:wght@400;500;600;700&display=swap">
<link rel="stylesheet" href="/static/css/app.css">
</head>
<body>
<canvas id="aura" aria-hidden="true"></canvas>
<div class="topline"></div>

<!-- OFFER BAR -->
<div class="offer" id="offerBar">
  <div class="offer-in">
    <div class="marquee" aria-hidden="true"><ul id="marqueeList"></ul></div>
    <button class="code-chip" id="codeChip" title="Copy code">
      <svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2"/><rect x="9" y="3" width="6" height="4" rx="1"/></svg>
      SAVE 10% <b>GALAXY10</b></button>
    <button class="offer-x" id="offerX" aria-label="Dismiss"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12"/></svg></button>
  </div>
</div>

<!-- HEADER -->
<header class="hd" id="hd">
  <div class="wrap hd-in">
    <a href="#" class="brand" aria-label="Galaxy Subz × Zayron — home"><img src="/static/img/logo.png" alt="Galaxy Subz x Zayron" onerror="this.style.display='none';this.nextElementSibling.style.display='inline-flex'"><span class="logofall" style="display:none;align-items:center;gap:6px;font-family:var(--display);font-weight:800;font-size:20px;letter-spacing:-.02em">Galaxy Subz&nbsp;<span style="background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent">× Zayron</span></span></a>
    <nav class="nav" aria-label="Primary">
      <a href="#" data-scroll="cat-entertainment">Shop</a>
      <a href="#" data-scroll="cat-iptv">IPTV</a>
      <a href="#" data-scroll="cat-players">Players</a>
      <a href="#" data-scroll="cat-tools">Tools &amp; VPN</a>
      <a href="#" data-toast="Resellers page — building in a later phase.">Resellers</a>
      <a href="#" data-toast="Blog — building in a later phase.">Blog</a>
      <a href="#" data-toast="About page — building in a later phase.">About</a>
    </nav>
    <div class="hd-sp"></div>
    <div class="hd-tools">
      <button class="icon-btn" id="searchBtn" aria-label="Search"><svg class="ic" viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg></button>
      <div class="pos-rel">
        <button class="region" id="regionBtn" aria-haspopup="true">
          <img class="flag" id="regionFlag" src="" alt=""><span id="regionLabel">PK · Rs</span>
          <svg class="ic ic-sm" viewBox="0 0 24 24" style="opacity:.5"><path d="m6 9 6 6 6-6"/></svg>
        </button>
        <div class="rmenu" id="regionMenu"></div>
      </div>
      <a class="btn btn-wa hd-wa" href="#" data-toast="Opens WhatsApp order — number set in admin.">
        <svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg><span class="label">Order on WhatsApp</span></a>
      <button class="icon-btn cart" aria-label="Order" data-toast="Your cart — building in a later phase.">
        <svg class="ic" viewBox="0 0 24 24"><path d="M6 6h15l-1.5 9h-12z"/><path d="M6 6 5 3H2"/><circle cx="9" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/></svg><span class="dot tnum">2</span></button>
      <button class="icon-btn burger" id="burger" aria-label="Menu"><svg class="ic" viewBox="0 0 24 24"><path d="M3 6h18M3 12h18M3 18h18"/></svg></button>
    </div>
  </div>
</header>

<!-- HERO -->
<section class="hero">
  <div class="wrap">
    <div class="stage-wrap" id="stageWrap"><div class="stage" id="stage" aria-label="Featured categories"></div></div>
    <div class="actionbar">
      <div class="ab-lead">
        <span class="ab-kick grad-text" id="abKick">Now showing</span>
        <span class="ab-title" id="abTitle">Premium Entertainment Subscriptions</span>
      </div>
      <div class="ab-cta">
        <a class="btn btn-primary" id="abBtn" href="#" data-scroll="cat-entertainment">Shop Entertainment</a>
        <a class="btn btn-ghost" href="#" data-toast="Free IPTV trial flow — building next.">Free IPTV trial</a>
      </div>
    </div>
  </div>
</section>

<!-- TRUST -->
<div class="wrap trust">
  <ul>
    <li><span class="ti"><svg class="ic" viewBox="0 0 24 24"><path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/></svg></span><div><b>Instant delivery</b><span>Automated, around the clock</span></div></li>
    <li><span class="ti"><svg class="ic" viewBox="0 0 24 24"><path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/><path d="m9 12 2 2 4-4"/></svg></span><div><b>Verified payments</b><span>We confirm, then deliver</span></div></li>
    <li><span class="ti"><svg class="ic" viewBox="0 0 24 24"><path d="M4 4h16v12H5.2L4 18V4Z"/><path d="M8 9h8M8 12h5"/></svg></span><div><b>Email &amp; PDF invoice</b><span>Every order, documented</span></div></li>
    <li><span class="ti"><svg class="ic" viewBox="0 0 24 24"><path d="M4 12a8 8 0 0 1 16 0v4a3 3 0 0 1-3 3h-2v-5h5M4 12v4h3v-5H4"/></svg></span><div><b>WhatsApp support</b><span>Real help when you need it</span></div></li>
  </ul>
</div>

<!-- CATALOGUE -->
<main id="catalog"></main>

<!-- BAND -->
<section class="band" style="background:linear-gradient(160deg,#0a0e22,#141a3a)">
  <img src="/static/img/banner-tools-desktop.jpg" alt="" onerror="this.remove()">
  <div class="band-in">
    <span class="eyebrow">Fully automated fulfilment</span>
    <h2>Order, pay, and get your login in minutes.</h2>
    <p>Pick a product, pay with a local method, Binance or TapTap, and our system verifies the payment and delivers your credentials or IPTV line automatically — no waiting for a human.</p>
    <div class="cta">
      <a class="btn btn-primary btn-lg" href="#" data-scroll="cat-entertainment">Browse the catalogue</a>
      <a class="btn btn-ghost btn-lg" href="#" data-toast="How delivery works — building next." style="background:transparent;color:#fff;box-shadow:inset 0 0 0 1px rgba(255,255,255,.3)">How it works</a>
    </div>
  </div>
</section>

<!-- REVIEWS -->
<section class="section">
  <div class="wrap">
    <div class="sec-head">
      <div class="lead"><span class="cat-tag grad-text"><span class="dot" style="background:var(--brand)"></span>What customers say</span><h2>Trusted by resellers and viewers</h2></div>
      <a class="view-all" href="#" data-toast="All reviews — building next.">Read all reviews</a>
    </div>
    <div class="rev-grid">
      <div class="tp-card">
        <div class="tp-score"><b class="tnum">4.7</b><span>/ 5</span></div>
        <div class="stars" id="tpStars"></div>
        <div class="tp-sub">Based on <b class="tnum">1,284</b> customer reviews</div>
        <div class="tp-logo"><svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg>Trustpilot</div>
      </div>
      <div class="rev-cards" id="revCards"></div>
    </div>
  </div>
</section>

<!-- VERIFIED BRANDS -->
<div class="house">
  <div class="wrap house-in">
    <span class="lbl"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/><path d="m9 12 2 2 4-4"/></svg>Verified brands in our family</span>
    <div class="brands">
      <a href="#" data-toast="galaxytools.net">galaxytools.net</a>
      <a href="#" data-toast="galaxy-tools.com">galaxy-tools.com</a>
      <a href="#" data-toast="zayron.tv">zayron.tv</a>
      <a href="#" data-toast="zayron.pro">zayron.pro</a>
    </div>
  </div>
</div>

<!-- FOOTER -->
<footer class="ft">
  <div class="wrap">
    <div class="ft-top">
      <div class="ft-brand">
        <img src="/static/img/logo.png" alt="Galaxy Subz x Zayron" onerror="this.style.display='none';this.nextElementSibling.style.display='inline-flex'"><span class="logofall" style="display:none;align-items:center;gap:6px;font-family:var(--display);font-weight:800;font-size:20px;letter-spacing:-.02em">Galaxy Subz&nbsp;<span style="background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent">× Zayron</span></span>
        <p>Premium digital subscriptions and IPTV, delivered instantly and backed by real support. One trusted home for streaming, tools, VPNs and more.</p>
        <div class="social">
          <a href="#" aria-label="WhatsApp" data-toast="WhatsApp link set in admin."><svg class="ic" viewBox="0 0 24 24"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg></a>
          <a href="#" aria-label="Instagram" data-toast="Instagram link set in admin."><svg class="ic" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none"/></svg></a>
          <a href="#" aria-label="Facebook" data-toast="Facebook link set in admin."><svg class="ic" viewBox="0 0 24 24"><path d="M14 9h3V5h-3c-2.2 0-4 1.8-4 4v2H7v4h3v6h4v-6h3l1-4h-4V9c0-.6.4-1 1-1Z"/></svg></a>
          <a href="#" aria-label="Telegram" data-toast="Telegram link set in admin."><svg class="ic" viewBox="0 0 24 24"><path d="m21 4-9 16-2.5-6.5L3 11l18-7Z"/><path d="M9.5 13.5 21 4"/></svg></a>
        </div>
      </div>
      <div class="ft-col"><h4>Shop</h4>
        <a href="#" data-scroll="cat-entertainment">Entertainment</a><a href="#" data-scroll="cat-iptv">IPTV services</a>
        <a href="#" data-scroll="cat-vpns">VPNs</a><a href="#" data-scroll="cat-tools">Tools</a><a href="#" data-scroll="cat-players">Player activation</a></div>
      <div class="ft-col"><h4>Company</h4>
        <a href="#" data-toast="About — later.">About us</a><a href="#" data-toast="Resellers — later.">Reseller panels</a>
        <a href="#" data-toast="Blog — later.">Blog</a><a href="#" data-toast="Contact — later.">Contact</a></div>
      <div class="ft-col"><h4>Support</h4>
        <a href="#" data-toast="Order lookup — later.">Track an order</a><a href="#" data-toast="IPTV tools — later.">Check line status</a>
        <a href="#" data-toast="Renewals — later.">Renew IPTV</a><a href="#" data-toast="FAQ — later.">FAQ &amp; policies</a></div>
    </div>
    <div class="ft-bottom">
      <span class="copy">© 2026 Galaxy Subz × Zayron. All rights reserved.</span>
      <div class="pays"><span class="pay">Pakistani banks</span><span class="pay">Binance</span><span class="pay">TapTap</span></div>
    </div>
  </div>
</footer>

<!-- SEARCH -->
<div class="ov" id="searchOv"><div class="search-panel" role="dialog" aria-label="Search">
  <div class="search-top">
    <svg class="ic" viewBox="0 0 24 24" style="color:var(--muted)"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
    <input id="searchInput" type="text" placeholder="Search Netflix, IPTV, VPN, Canva…" autocomplete="off"><kbd>Esc</kbd>
  </div>
  <div class="search-res" id="searchRes"></div>
</div></div>

<!-- DRAWER -->
<div class="scrim-el" id="scrim"></div>
<aside class="drawer" id="drawer" aria-label="Menu">
  <div class="drawer-top"><img src="/static/img/logo.png" alt="Galaxy Subz x Zayron" onerror="this.style.display='none';this.nextElementSibling.style.display='inline-flex'"><span class="logofall" style="display:none;align-items:center;gap:6px;font-family:var(--display);font-weight:800;font-size:20px;letter-spacing:-.02em">Galaxy Subz&nbsp;<span style="background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent">× Zayron</span></span><button class="icon-btn" id="drawerX" aria-label="Close"><svg class="ic" viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12"/></svg></button></div>
  <div class="drawer-body">
    <div class="drawer-cats" id="drawerCats"></div>
    <div class="drawer-links">
      <a href="#" data-toast="Resellers — later."><svg class="ic" viewBox="0 0 24 24"><path d="M3 7h18M3 12h18M3 17h18"/></svg>Reseller panels</a>
      <a href="#" data-toast="Blog — later."><svg class="ic" viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/></svg>Blog</a>
      <a href="#" data-toast="About — later."><svg class="ic" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 10v6M12 7v.5"/></svg>About us</a>
      <a href="#" data-toast="Track order — later."><svg class="ic" viewBox="0 0 24 24"><rect x="5" y="7" width="14" height="10" rx="1"/><path d="M5 10h14"/></svg>Track an order</a>
    </div>
  </div>
  <div class="drawer-foot">
    <div class="drawer-region" id="drawerRegion"></div>
    <a class="btn btn-wa" href="#" data-toast="Opens WhatsApp — number set in admin." style="justify-content:center"><svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>Order on WhatsApp</a>
  </div>
</aside>

<button class="toss" id="toss"></button>
<div class="toast" id="toast"></div>
<script>window.__DATA = <%- dataJson %>;</script>
<script src="/static/js/app.js" defer></script>
</body>
</html>
GSZ_EJS_EOF
cat > "$APP/public/css/app.css" <<'GSZ_CSS_EOF'
/* ============================================================
   GALAXY SUBZ × ZAYRON — storefront v2
   Light base, but saturated with the brand: violet→blue→cyan
   gradients, chrome, glass, cinematic dark product tiles that
   echo the banners, glossy gradient buttons, 3D tilt + a living
   brand aurora. Committed single light theme (brand decision).
   ============================================================ */
:root{
  color-scheme: light;

  /* neutrals — cool, biased toward the brand blue */
  --bg:        #f6f8ff;
  --bg-2:      #eef2fe;
  --surface:   #ffffff;
  --ink:       #0a0f24;
  --ink-2:     #434d69;
  --muted:     #7d87a1;
  --hair:      #e3e8f6;
  --hair-2:    #d2daee;

  /* brand */
  --violet:  #8a2bff;
  --blue:    #2a7bff;
  --azure:   #165ff0;
  --cyan:    #17cbf0;
  --magenta: #c23bff;
  --brand:   linear-gradient(118deg, #8a2bff 0%, #2a7bff 50%, #17cbf0 100%);
  --brand-soft: linear-gradient(118deg, #a14fff, #3f8bff, #35d6f5);
  --navy:   #0a0e24;
  --navy-2: #151c40;

  --positive:#16b765;
  --sale:    #ff4d6d;

  /* type */
  --display:'Schibsted Grotesk','Segoe UI',system-ui,sans-serif;
  --body:'Hanken Grotesk','Segoe UI',system-ui,sans-serif;

  --maxw:1600px;
  --gutter:clamp(16px,4vw,48px);
  --r-sm:9px; --r-md:14px; --r-lg:18px;

  --glow-brand:0 24px 60px -26px rgba(42,123,255,.6);
  --glow-violet:0 24px 60px -26px rgba(138,43,255,.5);
  --shadow-card:0 1px 2px rgba(10,15,36,.05),0 16px 34px -22px rgba(10,15,36,.3);
  --shadow-pop:0 24px 70px -24px rgba(10,15,36,.4);
  --ease:cubic-bezier(.22,.61,.36,1);
}

*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{
  margin:0; background:var(--bg); color:var(--ink);
  font-family:var(--body); font-size:16px; line-height:1.55; letter-spacing:-.003em;
  -webkit-font-smoothing:antialiased; text-rendering:optimizeLegibility; overflow-x:hidden;
}
h1,h2,h3,h4{font-family:var(--display);font-weight:700;line-height:1.08;letter-spacing:-.02em;margin:0;text-wrap:balance}
p{margin:0}
a{color:inherit;text-decoration:none}
img{max-width:100%;display:block}
button{font-family:inherit;cursor:pointer;border:0;background:none;color:inherit}
:focus-visible{outline:2px solid var(--azure);outline-offset:3px;border-radius:5px}
.tnum{font-variant-numeric:tabular-nums}

.wrap{max-width:var(--maxw);margin:0 auto;padding-inline:var(--gutter);position:relative}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0)}
.grad-text{background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent}

/* brand aurora (sits above the body ground, below content) */
#aura{position:fixed;inset:0;z-index:0;pointer-events:none}
.offer,.hd,main,.hero,footer,.band,.section,.house,.trust{position:relative;z-index:1}

/* chrome signature line at very top */
.topline{height:3px;background:var(--brand);position:relative;z-index:2}

/* icons */
.ic{width:20px;height:20px;stroke:currentColor;fill:none;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;flex:none}
.ic-sm{width:16px;height:16px}

/* ---------- buttons ---------- */
.btn{display:inline-flex;align-items:center;gap:8px;font-family:var(--display);font-weight:600;font-size:14px;
  letter-spacing:-.01em;border-radius:11px;padding:11px 18px;transition:all .25s var(--ease);white-space:nowrap;position:relative}
.btn-primary{background:var(--brand);color:#fff;box-shadow:var(--glow-brand);overflow:hidden}
.btn-primary:before{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(255,255,255,.35),transparent 46%);opacity:.9}
.btn-primary:hover{transform:translateY(-2px);filter:saturate(1.08) brightness(1.04);box-shadow:0 26px 54px -22px rgba(42,123,255,.8)}
.btn-ghost{background:#fff;color:var(--ink);box-shadow:inset 0 0 0 1px var(--hair-2)}
.btn-ghost:hover{box-shadow:inset 0 0 0 1.5px var(--azure);color:var(--azure);transform:translateY(-1px)}
.btn-wa{background:#1faa52;color:#fff}
.btn-wa:hover{background:#188a43;transform:translateY(-1px)}
.btn-lg{padding:14px 24px;font-size:15px;border-radius:12px}

/* ============================ OFFER BAR ============================ */
.offer{background:var(--navy);color:#fff;font-size:13px}
.offer-in{display:flex;align-items:center;gap:16px;height:40px;max-width:var(--maxw);margin:0 auto;padding-inline:var(--gutter)}
.marquee{flex:1;overflow:hidden;min-width:0;-webkit-mask-image:linear-gradient(90deg,transparent,#000 5%,#000 95%,transparent);mask-image:linear-gradient(90deg,transparent,#000 5%,#000 95%,transparent)}
.marquee ul{display:flex;gap:40px;list-style:none;margin:0;padding:0;white-space:nowrap;width:max-content;animation:scroll 32s linear infinite}
.marquee li{display:flex;align-items:center;gap:9px;color:#c7d0e6;font-weight:500}
.marquee li svg{stroke:var(--cyan)}
@keyframes scroll{to{transform:translateX(-50%)}}
.code-chip{display:inline-flex;align-items:center;gap:8px;background:linear-gradient(118deg,rgba(138,43,255,.25),rgba(23,203,240,.22));
  border:1px solid rgba(255,255,255,.22);padding:5px 11px;border-radius:8px;font-family:var(--display);font-weight:600;font-size:12px;flex:none;cursor:pointer}
.code-chip b{letter-spacing:.09em;color:#fff}
.offer-x{flex:none;color:#8591ad;display:grid;place-items:center;padding:4px}
.offer-x:hover{color:#fff}
@media(max-width:720px){.code-chip{display:none}}

/* ============================ HEADER ============================ */
.hd{position:sticky;top:env(safe-area-inset-top,0px);z-index:60;background:rgba(246,248,255,.78);
  backdrop-filter:saturate(1.3) blur(16px);border-bottom:1px solid transparent;transition:border-color .3s,box-shadow .3s}
.hd.scrolled{border-bottom-color:var(--hair);box-shadow:0 10px 30px -26px rgba(10,15,36,.6)}
.hd-in{display:flex;align-items:center;gap:22px;height:76px}
.brand{display:flex;align-items:center;flex:none}
.brand img{height:46px;width:auto}
.nav{display:flex;align-items:center;gap:2px;margin-left:6px}
.nav a{font-family:var(--display);font-weight:500;font-size:14.5px;color:var(--ink-2);padding:9px 13px;border-radius:9px;transition:.2s;position:relative}
.nav a:after{content:"";position:absolute;left:13px;right:13px;bottom:5px;height:2px;background:var(--brand);border-radius:2px;transform:scaleX(0);transform-origin:left;transition:transform .25s var(--ease)}
.nav a:hover{color:var(--ink)}
.nav a:hover:after{transform:scaleX(1)}
.hd-sp{flex:1}
.hd-tools{display:flex;align-items:center;gap:6px}
.icon-btn{width:43px;height:43px;border-radius:11px;display:grid;place-items:center;color:var(--ink-2);transition:.2s}
.icon-btn:hover{background:#fff;color:var(--azure);box-shadow:var(--shadow-card)}
.region{display:inline-flex;align-items:center;gap:8px;height:43px;padding:0 13px;border-radius:11px;color:var(--ink-2);
  font-family:var(--display);font-weight:600;font-size:13px;transition:.2s}
.region:hover{background:#fff;color:var(--ink);box-shadow:var(--shadow-card)}
.region .flag{width:17px;height:12px;border-radius:2px;object-fit:cover;box-shadow:inset 0 0 0 1px rgba(0,0,0,.08)}
.cart{position:relative}
.cart .dot{position:absolute;top:6px;right:6px;width:16px;height:16px;border-radius:50%;background:var(--magenta);color:#fff;
  font-size:10px;font-weight:700;display:grid;place-items:center;font-family:var(--display)}
.burger{display:none}
@media(max-width:1120px){.nav{display:none}.hd-wa .label{display:none}}
@media(max-width:860px){
  .hd-in{height:64px;gap:14px}.brand img{height:34px}
  .region,.hd-wa,.cart{display:none}.burger{display:grid}
}

/* ============================ HERO ============================ */
.hero{padding-top:clamp(20px,2.6vw,38px)}
.stage-wrap{border-radius:calc(var(--r-lg) + 2px);padding:2px;background:var(--brand);box-shadow:var(--glow-brand);
  perspective:1400px}
.stage{position:relative;border-radius:var(--r-lg);overflow:hidden;background:#0b0d16;aspect-ratio:1942/809;
  transform-style:preserve-3d;transition:transform .3s var(--ease)}
.slide{position:absolute;inset:0;opacity:0;transition:opacity 1.1s var(--ease);pointer-events:none}
.slide.on{opacity:1;pointer-events:auto}
.slide img{width:100%;height:100%;object-fit:cover;object-position:left center;transition:transform .5s var(--ease)}
.stage .arrow{position:absolute;top:50%;transform:translateY(-50%);z-index:4;width:46px;height:46px;border-radius:50%;
  background:rgba(10,14,36,.35);backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,.25);color:#fff;display:grid;place-items:center;opacity:0;transition:.3s}
.stage:hover .arrow{opacity:1}.stage .arrow:hover{background:rgba(10,14,36,.6)}
.arrow.prev{left:16px}.arrow.next{right:16px}
.dots{position:absolute;left:0;right:0;bottom:16px;z-index:4;display:flex;justify-content:center;gap:8px}
.dots button{width:8px;height:8px;border-radius:50%;background:rgba(255,255,255,.45);transition:.3s}
.dots button.on{background:#fff;width:28px;border-radius:5px}

.actionbar{display:flex;align-items:center;gap:20px;margin-top:18px;padding:16px 20px;border-radius:var(--r-md);
  background:var(--surface);box-shadow:var(--shadow-card)}
.ab-lead{display:flex;flex-direction:column;gap:3px;min-width:0}
.ab-kick{font-family:var(--display);font-weight:700;font-size:12px;letter-spacing:.05em;text-transform:uppercase}
.ab-title{font-family:var(--display);font-weight:600;font-size:17px;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ab-cta{display:flex;gap:10px;margin-left:auto;flex:none}
@media(max-width:720px){
  .hero{padding-top:12px}
  .stage{aspect-ratio:1536/1024;border-radius:14px}.stage .arrow{display:none}
  .actionbar{flex-direction:column;align-items:stretch;gap:12px;padding:14px}
  .ab-cta{margin-left:0}.ab-cta .btn{flex:1;justify-content:center}.ab-title{white-space:normal}
}

/* ============================ TRUST ============================ */
.trust{margin-top:clamp(28px,3.2vw,44px)}
.trust ul{list-style:none;margin:0;padding:24px 0;display:grid;grid-template-columns:repeat(4,1fr);
  border-top:1px solid var(--hair);border-bottom:1px solid var(--hair)}
.trust li{display:flex;align-items:center;gap:13px;padding:0 24px;position:relative}
.trust li+li:before{content:"";position:absolute;left:0;top:4px;bottom:4px;width:1px;background:var(--hair)}
.trust .ti{width:40px;height:40px;border-radius:11px;background:var(--brand);display:grid;place-items:center;color:#fff;flex:none;box-shadow:var(--glow-brand)}
.trust .ti svg{stroke:#fff}
.trust b{font-family:var(--display);font-weight:600;font-size:14px;display:block}
.trust span{font-size:12.5px;color:var(--muted);line-height:1.35}
@media(max-width:860px){.trust ul{grid-template-columns:repeat(2,1fr);gap:18px 0;padding:18px 0}.trust li{padding:0 14px}.trust li:nth-child(odd):before{display:none}}
@media(max-width:480px){.trust .ti{width:34px;height:34px}}

/* ============================ SECTION + RAIL ============================ */
.section{padding-block:clamp(40px,5vw,74px)}
.sec-alt{background:var(--bg-2)}
.sec-head{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;margin-bottom:26px}
.sec-head .lead{display:flex;flex-direction:column;gap:7px;min-width:0}
.cat-tag{display:inline-flex;align-items:center;gap:9px;font-family:var(--display);font-weight:700;font-size:12.5px;
  letter-spacing:.04em;text-transform:uppercase}
.cat-tag .dot{width:22px;height:5px;border-radius:3px}
.sec-head h2{font-size:clamp(23px,2.7vw,32px)}
.view-all{display:inline-flex;align-items:center;gap:8px;font-family:var(--display);font-weight:600;font-size:14px;color:var(--ink);
  padding:10px 15px;border-radius:10px;box-shadow:inset 0 0 0 1px var(--hair-2);transition:.2s;flex:none;background:#fff}
.view-all:hover{box-shadow:inset 0 0 0 1.5px var(--azure);color:var(--azure)}
.view-all .count{color:var(--muted);font-weight:500}

.rail{display:grid;grid-auto-flow:column;grid-auto-columns:246px;gap:18px;overflow-x:auto;scroll-snap-type:x mandatory;
  padding:4px 0 10px;margin-inline:calc(var(--gutter)*-1);padding-inline:var(--gutter);
  scrollbar-width:thin;scrollbar-color:var(--hair-2) transparent}
.rail::-webkit-scrollbar{height:8px}.rail::-webkit-scrollbar-thumb{background:var(--hair-2);border-radius:4px}
.rail>*{scroll-snap-align:start}
@media(max-width:640px){.rail{grid-auto-columns:78vw}}

/* ============================ PRODUCT CARD ============================ */
.card{display:flex;flex-direction:column;background:var(--surface);border-radius:var(--r-md);overflow:hidden;
  box-shadow:0 1px 2px rgba(10,15,36,.05),0 10px 24px -20px rgba(10,15,36,.3);transition:box-shadow .3s var(--ease),transform .3s var(--ease);
  width:100%;text-align:left}
.card:hover{box-shadow:var(--shadow-card)}
/* cinematic branded tile (echoes the banners) */
.thumb{position:relative;aspect-ratio:16/10;overflow:hidden;transform-style:preserve-3d;transition:transform .2s var(--ease)}
.tile{position:absolute;inset:0;background:
  radial-gradient(130% 100% at 24% -10%, var(--g1) 0%, transparent 56%),
  linear-gradient(162deg,#111735,#090c1e);
  display:flex;flex-direction:column;justify-content:flex-end;padding:15px;transition:transform .5s var(--ease)}
.tile:before{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(255,255,255,.16),transparent 38%);opacity:.9}
.tile:after{content:"";position:absolute;inset:0;box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)}
.card:hover .tile{transform:scale(1.04)}
.tile .cat-mini{position:absolute;top:13px;left:14px;font-family:var(--display);font-weight:600;font-size:10px;letter-spacing:.09em;
  text-transform:uppercase;color:rgba(255,255,255,.62);z-index:2}
.tile .wm{position:absolute;top:12px;right:13px;font-family:var(--display);font-weight:800;font-size:11px;letter-spacing:.02em;
  color:rgba(255,255,255,.5);z-index:2}
.tile .pname{position:relative;z-index:2;font-family:var(--display);font-weight:800;font-size:21px;line-height:1.04;letter-spacing:-.015em;
  background:linear-gradient(180deg,#fff,#c3d0ea);-webkit-background-clip:text;background-clip:text;color:transparent;max-width:94%}
.tile .save-pill{position:absolute;bottom:14px;right:13px;z-index:2;background:var(--sale);color:#fff;font-family:var(--display);
  font-weight:700;font-size:11px;padding:4px 8px;border-radius:7px;box-shadow:0 6px 14px -5px rgba(255,77,109,.8)}
.card .body{padding:14px 15px 16px;display:flex;flex-direction:column;gap:7px;flex:1}
.card .meta{display:flex;align-items:center;gap:7px;font-size:11.5px;color:var(--muted);font-weight:500}
.card .meta .d{width:5px;height:5px;border-radius:50%;background:var(--positive)}
.card .plan{font-family:var(--display);font-weight:600;font-size:13px;color:var(--azure)}
.card .pdesc{font-size:13px;color:var(--ink-2);line-height:1.4;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;min-height:36px}
.card .foot{margin-top:auto;display:flex;align-items:flex-end;justify-content:space-between;gap:10px;padding-top:6px}
.price{display:flex;flex-direction:column;gap:1px}
.price .was{font-size:12px;color:var(--muted);text-decoration:line-through}
.price .now{font-family:var(--display);font-weight:800;font-size:20px;color:var(--ink);letter-spacing:-.015em}
.price .now .cur{font-size:12.5px;font-weight:600;color:var(--ink-2);margin-right:2px}
.buy{width:40px;height:40px;border-radius:11px;background:var(--brand);color:#fff;display:grid;place-items:center;flex:none;
  box-shadow:var(--glow-brand);transition:.25s;overflow:hidden;position:relative}
.buy:before{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(255,255,255,.35),transparent 50%)}
.card:hover .buy{transform:scale(1.06) rotate(-3deg)}

/* ============================ IPTV EDITORIAL ============================ */
.iptv-promo{position:relative;border-radius:var(--r-md);overflow:hidden;color:#fff;padding:30px;margin-bottom:22px;
  display:flex;flex-direction:column;justify-content:flex-end;min-height:240px}
.iptv-promo img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.iptv-promo .scrim{position:absolute;inset:0;background:linear-gradient(100deg,rgba(7,10,26,.9) 0%,rgba(7,10,26,.62) 46%,rgba(7,10,26,.12) 100%)}
.iptv-promo>*{position:relative}
.iptv-promo h3{font-size:clamp(22px,2.6vw,30px);max-width:18ch}
.iptv-promo p{font-size:14.5px;color:#c9d2e8;margin:9px 0 18px;max-width:40ch}
.iptv-actions{display:flex;flex-wrap:wrap;gap:10px}
.chip{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.22);
  color:#fff;font-family:var(--display);font-weight:600;font-size:13px;padding:10px 15px;border-radius:10px;transition:.2s}
.chip:hover{background:rgba(255,255,255,.2)}
.chip.solid{background:var(--brand);border-color:transparent;box-shadow:var(--glow-brand)}

/* player feature trio */
.trio{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}
.feat{position:relative;border-radius:var(--r-md);overflow:hidden;color:#fff;min-height:230px;display:flex;flex-direction:column;
  justify-content:flex-end;padding:24px;background:
  radial-gradient(130% 100% at 20% -10%, var(--g1), transparent 60%),linear-gradient(160deg,#121838,#0a0e22);
  box-shadow:var(--shadow-card);transition:transform .3s var(--ease),box-shadow .3s}
.feat:before{content:"";position:absolute;inset:0;box-shadow:inset 0 0 0 1px rgba(255,255,255,.08);border-radius:inherit}
.feat:hover{transform:translateY(-4px);box-shadow:var(--glow-brand)}
.feat h4{font-size:22px}.feat p{font-size:13.5px;color:rgba(255,255,255,.8);margin:7px 0 15px}
.feat .fp{font-family:var(--display);font-weight:800;font-size:22px}
.feat .fp .cur{font-size:13px;color:rgba(255,255,255,.75);font-weight:600}
@media(max-width:860px){.trio{grid-template-columns:1fr}}

/* mini services */
.mini{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}
.mini .thumb{aspect-ratio:21/9}
@media(max-width:860px){.mini{grid-template-columns:1fr}}

/* ============================ CINEMATIC BAND ============================ */
.band{overflow:hidden;color:#fff;isolation:isolate}
.band img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;z-index:-2}
.band:after{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(94deg,rgba(7,10,26,.94) 0%,rgba(7,10,26,.74) 44%,rgba(10,14,40,.4) 100%)}
.band-in{max-width:var(--maxw);margin:0 auto;padding:clamp(56px,7vw,110px) var(--gutter)}
.band .eyebrow{font-family:var(--display);font-weight:700;font-size:13px;letter-spacing:.05em;text-transform:uppercase;
  background:var(--brand-soft);-webkit-background-clip:text;background-clip:text;color:transparent}
.band h2{font-size:clamp(28px,4vw,48px);max-width:17ch;margin:14px 0 16px}
.band p{font-size:16px;color:#c9d2e8;max-width:54ch;margin-bottom:28px}
.band .cta{display:flex;flex-wrap:wrap;gap:12px}

/* ============================ REVIEWS ============================ */
.rev-grid{display:grid;grid-template-columns:310px 1fr;gap:32px;align-items:start}
.tp-card{border-radius:var(--r-md);padding:26px;background:var(--surface);box-shadow:var(--shadow-card);position:sticky;top:98px}
.tp-score{display:flex;align-items:baseline;gap:8px;font-family:var(--display)}
.tp-score b{font-size:46px;font-weight:800;letter-spacing:-.03em}
.tp-score span{color:var(--muted);font-size:14px}
.stars{display:flex;gap:3px;margin:12px 0 10px}.stars svg{width:23px;height:23px;fill:#00b67a}
.tp-card .tp-sub{font-size:13.5px;color:var(--ink-2)}
.tp-card .tp-logo{margin-top:18px;padding-top:18px;border-top:1px solid var(--hair);display:flex;align-items:center;gap:8px;font-family:var(--display);font-weight:700;font-size:15px}
.tp-card .tp-logo svg{width:18px;height:18px;fill:#00b67a}
.rev-cards{display:grid;grid-template-columns:repeat(2,1fr);gap:16px}
.rev{border-radius:var(--r-md);padding:21px;background:var(--surface);box-shadow:var(--shadow-card);display:flex;flex-direction:column;gap:12px}
.rev .rev-stars{display:flex;gap:2px}.rev .rev-stars svg{width:16px;height:16px;fill:#00b67a}
.rev p{font-size:14.5px;color:var(--ink);line-height:1.5}
.rev .who{display:flex;align-items:center;gap:11px;margin-top:auto}
.rev .av{width:36px;height:36px;border-radius:50%;background:var(--brand);color:#fff;display:grid;place-items:center;font-family:var(--display);font-weight:700;font-size:13px}
.rev .who b{font-family:var(--display);font-size:13.5px;font-weight:600;display:block}
.rev .who span{font-size:12px;color:var(--muted)}
@media(max-width:920px){.rev-grid{grid-template-columns:1fr}.tp-card{position:static}.rev-cards{grid-template-columns:1fr}}

/* ============================ VERIFIED BRANDS ============================ */
.house{border-top:1px solid var(--hair);padding-block:30px}
.house-in{display:flex;align-items:center;gap:26px;flex-wrap:wrap;justify-content:center}
.house .lbl{display:flex;align-items:center;gap:8px;color:var(--muted);font-size:13px;font-weight:500}
.house .lbl svg{stroke:var(--positive)}
.house .brands{display:flex;flex-wrap:wrap;gap:10px 22px;justify-content:center}
.house .brands a{font-family:var(--display);font-weight:600;font-size:14.5px;color:var(--ink-2);transition:.2s;display:inline-flex;align-items:center;gap:8px}
.house .brands a:hover{color:var(--azure)}
.house .brands a:before{content:"";width:7px;height:7px;border-radius:50%;background:var(--brand)}

/* ============================ FOOTER ============================ */
.ft{background:var(--navy);color:#cdd6ea;padding-block:clamp(48px,5vw,68px) 32px;margin-top:8px}
.ft .wrap{position:relative;z-index:1}
.ft-top{display:grid;grid-template-columns:1.5fr 1fr 1fr 1fr;gap:40px;padding-bottom:40px;border-bottom:1px solid rgba(255,255,255,.1)}
.ft-brand img{height:44px;margin-bottom:16px;filter:drop-shadow(0 6px 20px rgba(42,123,255,.4))}
.ft-brand p{font-size:14px;color:#9aa6c4;max-width:34ch;margin-bottom:18px}
.social{display:flex;gap:10px}
.social a{width:42px;height:42px;border-radius:11px;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);
  display:grid;place-items:center;color:#cdd6ea;transition:.25s}
.social a:hover{background:var(--brand);border-color:transparent;color:#fff;transform:translateY(-2px);box-shadow:var(--glow-brand)}
.ft-col h4{font-family:var(--display);font-size:13px;font-weight:700;letter-spacing:.03em;text-transform:uppercase;margin-bottom:16px;color:#fff}
.ft-col a{display:block;font-size:14px;color:#9aa6c4;padding:6px 0;transition:.2s}
.ft-col a:hover{color:var(--cyan)}
.ft-bottom{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;padding-top:26px}
.ft-bottom .copy{font-size:13px;color:#7c88a8}
.pays{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.pay{height:32px;padding:0 12px;border-radius:8px;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);
  display:inline-flex;align-items:center;font-family:var(--display);font-weight:600;font-size:12px;color:#cdd6ea}
@media(max-width:920px){.ft-top{grid-template-columns:1fr 1fr;gap:32px}.ft-brand{grid-column:1/-1}}

/* ============================ SEARCH OVERLAY ============================ */
.ov{position:fixed;inset:0;z-index:100;background:rgba(10,15,36,.5);backdrop-filter:blur(4px);display:none;align-items:flex-start;justify-content:center;padding:13vh 16px 16px}
.ov.on{display:flex}
.search-panel{width:100%;max-width:640px;background:#fff;border-radius:18px;box-shadow:var(--shadow-pop);overflow:hidden}
.search-top{display:flex;align-items:center;gap:12px;padding:17px 18px;border-bottom:1px solid var(--hair)}
.search-top input{flex:1;border:0;outline:0;font-family:var(--body);font-size:17px;color:var(--ink);background:none}
.search-top input::placeholder{color:var(--muted)}
.search-top kbd{font-family:var(--display);font-size:11px;color:var(--muted);background:var(--bg-2);padding:3px 7px;border-radius:5px}
.search-res{max-height:52vh;overflow-y:auto;padding:8px}
.sres{display:flex;align-items:center;gap:13px;padding:10px 12px;border-radius:11px;cursor:pointer;width:100%}
.sres:hover{background:var(--bg-2)}
.sres .sq{width:42px;height:42px;border-radius:10px;flex:none;display:grid;place-items:center;color:#fff;font-family:var(--display);font-weight:800;font-size:13px;
  background:radial-gradient(120% 100% at 25% 0%,var(--g1),transparent 60%),linear-gradient(160deg,#121838,#0a0e22)}
.sres .si{flex:1;min-width:0;text-align:left}
.sres .si b{font-family:var(--display);font-weight:600;font-size:14.5px;display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.sres .si span{font-size:12px;color:var(--muted)}
.sres .sp{font-family:var(--display);font-weight:800;font-size:14px;color:var(--azure)}
.search-empty{padding:40px 20px;text-align:center;color:var(--muted);font-size:14px}
.search-lbl{padding:6px 12px;font-size:11px;color:var(--muted);font-family:var(--display);font-weight:700;letter-spacing:.05em;text-transform:uppercase}

/* ============================ DRAWER ============================ */
.scrim-el{position:fixed;inset:0;z-index:90;background:rgba(10,15,36,.45);opacity:0;visibility:hidden;transition:.3s}
.scrim-el.on{opacity:1;visibility:visible}
.drawer{position:fixed;top:0;right:0;bottom:0;width:min(88vw,380px);z-index:95;background:#fff;transform:translateX(100%);transition:transform .34s var(--ease);display:flex;flex-direction:column;box-shadow:var(--shadow-pop)}
.drawer.on{transform:none}
.drawer-top{display:flex;align-items:center;justify-content:space-between;padding:18px;border-bottom:1px solid var(--hair)}
.drawer-top img{height:32px}
.drawer-body{flex:1;overflow-y:auto;padding:18px}
.drawer-cats{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:22px}
.dcat{display:flex;flex-direction:column;gap:9px;padding:15px;border-radius:13px;color:#fff;min-height:92px;justify-content:space-between;
  background:radial-gradient(120% 100% at 25% 0%,var(--g1),transparent 62%),linear-gradient(160deg,#121838,#0a0e22)}
.dcat b{font-family:var(--display);font-weight:700;font-size:14px;line-height:1.15}.dcat span{font-size:11px;opacity:.8}
.drawer-links{display:flex;flex-direction:column;gap:2px;margin-bottom:22px}
.drawer-links a{display:flex;align-items:center;gap:12px;padding:12px 10px;border-radius:10px;font-family:var(--display);font-weight:500;font-size:15px;color:var(--ink)}
.drawer-links a:hover{background:var(--bg-2)}
.drawer-foot{padding:18px;border-top:1px solid var(--hair);display:flex;flex-direction:column;gap:12px}
.drawer-region{display:flex;gap:8px}
.drawer-region button{flex:1;padding:10px;border-radius:10px;box-shadow:inset 0 0 0 1px var(--hair);font-family:var(--display);font-weight:600;font-size:13px;color:var(--ink-2)}
.drawer-region button.on{background:var(--brand);color:#fff;box-shadow:none}

/* ============================ TOSS + TOAST ============================ */
.toss{position:fixed;left:18px;bottom:18px;z-index:80;max-width:300px;background:#fff;border-radius:13px;box-shadow:var(--shadow-pop);
  padding:12px 14px;display:flex;align-items:center;gap:12px;cursor:pointer;transform:translateY(150%);opacity:0;transition:transform .55s var(--ease),opacity .4s}
.toss.on{transform:none;opacity:1}
.toss .tq{width:40px;height:40px;border-radius:10px;flex:none;display:grid;place-items:center;color:#fff;font-family:var(--display);font-weight:800;font-size:13px;
  background:radial-gradient(120% 100% at 25% 0%,var(--g1),transparent 60%),linear-gradient(160deg,#121838,#0a0e22)}
.toss .ti2{min-width:0}
.toss .ti2 .t1{font-size:11px;color:var(--positive);font-weight:700;display:flex;align-items:center;gap:5px;font-family:var(--display)}
.toss .ti2 .t1 .d{width:6px;height:6px;border-radius:50%;background:var(--positive)}
.toss .ti2 b{font-family:var(--display);font-size:13.5px;font-weight:600;display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.toss .ti2 span{font-size:11.5px;color:var(--muted)}
.toss .tx{flex:none;color:var(--muted);align-self:flex-start}
@media(max-width:520px){.toss{left:12px;right:12px;bottom:12px;max-width:none}}
.toast{position:fixed;left:50%;bottom:26px;transform:translateX(-50%) translateY(150%);z-index:120;background:var(--navy);color:#fff;
  font-family:var(--display);font-weight:500;font-size:14px;padding:13px 22px;border-radius:12px;box-shadow:var(--shadow-pop);transition:transform .4s var(--ease);max-width:90vw;text-align:center}
.toast.on{transform:translateX(-50%)}

.rmenu{position:absolute;top:calc(100% + 6px);right:0;background:#fff;border-radius:13px;box-shadow:var(--shadow-pop);padding:6px;min-width:194px;display:none;z-index:70}
.rmenu.on{display:block}
.rmenu button{display:flex;align-items:center;gap:10px;width:100%;padding:10px 11px;border-radius:9px;font-size:13.5px;font-family:var(--display);font-weight:500;color:var(--ink);text-align:left}
.rmenu button:hover{background:var(--bg-2)}.rmenu button.on{color:var(--azure);font-weight:600}
.rmenu .flag{width:18px;height:13px;border-radius:2px;flex:none;box-shadow:inset 0 0 0 1px rgba(0,0,0,.08)}
.pos-rel{position:relative}

@media(prefers-reduced-motion:reduce){
  *{animation-duration:.001ms!important;transition-duration:.08s!important}
  .marquee ul{animation:none}
}

/* hero slide image must paint above the gradient placeholder */
.slide picture{position:absolute;inset:0;display:block;z-index:1}
.slide picture img{position:absolute;inset:0;width:100%;height:100%}
GSZ_CSS_EOF
cat > "$APP/public/js/app.js" <<'GSZ_JS_EOF'
/* ===== DATA — injected by the server from the database (window.__DATA) ===== */
const D=(typeof window!=='undefined'&&window.__DATA)?window.__DATA:{cats:[],products:[],banners:[],reviews:[],settings:{}};
const COLOR={entertainment:'#6a46ff',sports:'#18b0a0',iptv:'#2a7bff',vpns:'#3f73c9',tools:'#9a3bff',zoom:'#2e86f0',players:'#17cbf0',profiles:'#19b6e8',smm:'#c23bff'};
const CATS=(D.cats||[]).map(c=>({id:c.slug,name:c.name,tag:c.tag,glyph:c.glyph,g1:COLOR[c.slug]||'#2a7bff'}));
const BANMAP={};(D.banners||[]).forEach(b=>{(BANMAP[b.category_slug]=BANMAP[b.category_slug]||{})[b.device]=b;});
function banFile(slug,device){const g=BANMAP[slug];return g&&g[device]?g[device].filename:null;}
const P=(D.products||[]).map(p=>({cat:p.cat,name:p.name,plan:p.plan,price:+p.price,old:+p.old||0,desc:p.desc,delivery:p.delivery}));

const SLIDE_ORDER=['entertainment','iptv','vpns','tools','players'];
const SLIDES=SLIDE_ORDER.filter(s=>BANMAP[s]).map(s=>{const cat=CATS.find(c=>c.id===s)||{name:s};return {key:s,title:((BANMAP[s].desktop||BANMAP[s].mobile||{}).title)||cat.name,desktop:banFile(s,'desktop'),mobile:banFile(s,'mobile'),btn:'Shop '+cat.name,target:'cat-'+s};});
const ICON={
  film:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 4v16M17 4v16M3 9h4M3 15h4M17 9h4M17 15h4"/>',
  trophy:'<path d="M7 4h10v4a5 5 0 0 1-10 0V4Z"/><path d="M7 6H4v2a3 3 0 0 0 3 3M17 6h3v2a3 3 0 0 1-3 3M9 15h6M8 20h8M12 15v5"/>',
  tv:'<rect x="3" y="6" width="18" height="12" rx="2"/><path d="m8 3 4 3 4-3"/>',
  shield:'<path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/>',
  tool:'<path d="M14 7a3.5 3.5 0 0 0-4.8 4.5L4 16.7 7.3 20l5.2-5.2A3.5 3.5 0 0 0 17 10l-2.3 2.3-1.9-1.9L15 8"/>',
  video:'<rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/>',
  play:'<circle cx="12" cy="12" r="9"/><path d="m10 9 5 3-5 3V9Z" fill="currentColor" stroke="none"/>',
  user:'<circle cx="12" cy="8" r="4"/><path d="M5 20a7 7 0 0 1 14 0"/>',
  mega:'<path d="M4 10v4l10 4V6L4 10Z"/><path d="M14 8a4 4 0 0 1 0 8M7 14v3a2 2 0 0 0 4 0"/>',
};
const catOf=id=>CATS.find(c=>c.id===id);
const initials=n=>n.replace(/[^A-Za-z0-9 ]/g,'').split(' ').filter(Boolean).slice(0,2).map(w=>w[0]).join('').toUpperCase();

/* ===== region / currency (preview rates — real system uses live FX) ===== */
const FLAG={
 PK:"data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 3 2'%3E%3Crect width='3' height='2' fill='%2301411e'/%3E%3Crect width='.75' height='2' fill='%23fff'/%3E%3Ccircle cx='2.02' cy='1' r='.42' fill='%23fff'/%3E%3Ccircle cx='2.16' cy='.92' r='.4' fill='%2301411e'/%3E%3C/svg%3E",
 US:"data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 3 2'%3E%3Crect width='3' height='2' fill='%23b22234'/%3E%3Cg fill='%23fff'%3E%3Crect y='.15' width='3' height='.15'/%3E%3Crect y='.46' width='3' height='.15'/%3E%3Crect y='.77' width='3' height='.15'/%3E%3Crect y='1.08' width='3' height='.15'/%3E%3Crect y='1.38' width='3' height='.15'/%3E%3Crect y='1.69' width='3' height='.15'/%3E%3C/g%3E%3Crect width='1.3' height='1.08' fill='%233c3b6e'/%3E%3C/svg%3E",
 GB:"data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 60 40'%3E%3Crect width='60' height='40' fill='%23012169'/%3E%3Cpath d='M0 0l60 40M60 0L0 40' stroke='%23fff' stroke-width='8'/%3E%3Cpath d='M0 0l60 40M60 0L0 40' stroke='%23c8102e' stroke-width='4'/%3E%3Cpath d='M30 0v40M0 20h60' stroke='%23fff' stroke-width='12'/%3E%3Cpath d='M30 0v40M0 20h60' stroke='%23c8102e' stroke-width='7'/%3E%3C/svg%3E",
 AE:"data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 3 2'%3E%3Crect width='3' height='.667' fill='%23009e49'/%3E%3Crect y='.667' width='3' height='.667' fill='%23fff'/%3E%3Crect y='1.333' width='3' height='.667' fill='%23000'/%3E%3Crect width='.75' height='2' fill='%23ce1126'/%3E%3C/svg%3E",
};
const REGIONS=[
  {code:'PK',label:'PK · Rs',cur:'Rs',rate:1},
  {code:'US',label:'US · $',cur:'$',rate:0.0036},
  {code:'GB',label:'UK · £',cur:'£',rate:0.0028},
  {code:'AE',label:'UAE · AED',cur:'AED',rate:0.013},
];
let REGION=REGIONS[0];
function money(pkr){const{rate,cur}=REGION;if(cur==='Rs')return{cur:'Rs',val:Math.round(pkr).toLocaleString('en-US')};
  const v=pkr*rate;return{cur,val:(v<10?v.toFixed(2):Math.round(v).toLocaleString('en-US'))}}
function priceHTML(p){const n=money(p.price);let was='';
  if(p.old){const w=money(p.old);was=`<span class="was tnum">${w.cur} ${w.val}</span>`}
  return `<div class="price">${was}<span class="now tnum"><span class="cur">${n.cur}</span>${n.val}</span></div>`}

function cardHTML(p){const c=catOf(p.cat);
  return `<article class="card" data-name="${p.name}" data-plan="${p.plan}">
    <div class="thumb" data-tilt><div class="tile" style="--g1:${c.g1}">
      <span class="cat-mini">${c.tag}</span><span class="wm">GS×ZD</span>
      <span class="pname">${p.name}</span>
      ${p.old?`<span class="save-pill">−${Math.round((1-p.price/p.old)*100)}%</span>`:''}
    </div></div>
    <div class="body">
      <div class="meta"><span class="d"></span>${p.delivery}</div>
      <span class="plan">${p.plan}</span>
      <p class="pdesc">${p.desc}.</p>
      <div class="foot">${priceHTML(p)}<span class="buy" aria-hidden="true"><svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M5 12h14M13 6l6 6-6 6"/></svg></span></div>
    </div></article>`}

function sectionHead(c){const n=P.filter(p=>p.cat===c.id).length;
  return `<div class="sec-head"><div class="lead">
    <span class="cat-tag grad-text"><span class="dot" style="background:var(--brand)"></span>${c.tag}</span>
    <h2 id="cat-${c.id}">${c.name}</h2></div>
    <a class="view-all" href="#" data-toast="All ${c.name} — building next.">View all <span class="count tnum">${n}</span></a></div>`}

function buildCatalogue(){
  const prods=id=>P.filter(p=>p.cat===id);let html='';
  let c=catOf('entertainment');
  html+=`<section class="section"><div class="wrap">${sectionHead(c)}<div class="rail">${prods('entertainment').map(cardHTML).join('')}</div></div></section>`;
  c=catOf('iptv');
  html+=`<section class="section sec-alt"><div class="wrap">${sectionHead(c)}
    <div class="iptv-promo" style="background:radial-gradient(130% 100% at 20% -10%, ${COLOR.iptv}, transparent 60%),linear-gradient(160deg,#121838,#0a0e22)"><img src="/static/img/${banFile('iptv','desktop')||''}" alt="" onerror="this.remove()"><div class="scrim"></div>
      <h3>Thousands of live channels, worldwide</h3>
      <p>Generate a trial or paid line, check status or renew — handled automatically with the bot.</p>
      <div class="iptv-actions"><a class="chip solid" href="#" data-toast="Free IPTV trial — strict anti-abuse, building next.">Free 24-hour trial</a>
        <a class="chip" href="#" data-toast="Check line status — building next.">Check line status</a>
        <a class="chip" href="#" data-toast="Renewal flow — building next.">Renew a line</a></div></div>
    <div class="rail">${prods('iptv').map(cardHTML).join('')}</div></div></section>`;
  c=catOf('vpns');
  html+=`<section class="section"><div class="wrap">${sectionHead(c)}<div class="rail">${prods('vpns').map(cardHTML).join('')}</div></div></section>`;
  c=catOf('tools');
  html+=`<section class="section sec-alt"><div class="wrap">${sectionHead(c)}<div class="rail">${prods('tools').map(cardHTML).join('')}</div></div></section>`;
  c=catOf('players');
  html+=`<section class="section"><div class="wrap">${sectionHead(c)}<div class="trio">
    ${prods('players').map(p=>`<button class="feat" data-name="${p.name}" data-plan="${p.plan}" style="--g1:${catOf('players').g1}">
      <h4>${p.name}</h4><p>${p.desc}. ${p.delivery}.</p><div class="fp tnum"><span class="cur">${money(p.price).cur} </span>${money(p.price).val}</div></button>`).join('')}
    <button class="feat" style="--g1:#2a7bff" data-toast="Zayron Player — coming to the catalogue."><h4>Zayron Player</h4><p>Our own premium player. Activation plans coming soon.</p><div class="fp" style="font-size:15px;opacity:.85">Coming soon</div></button>
  </div></div></section>`;
  c=catOf('sports');
  html+=`<section class="section sec-alt"><div class="wrap">${sectionHead(c)}<div class="rail">${prods('sports').map(cardHTML).join('')}</div></div></section>`;
  c=catOf('zoom');
  html+=`<section class="section"><div class="wrap">${sectionHead(c)}<div class="rail">${prods('zoom').map(cardHTML).join('')}</div></div></section>`;
  html+=`<section class="section sec-alt"><div class="wrap">
    <div class="sec-head"><div class="lead"><span class="cat-tag grad-text"><span class="dot" style="background:var(--brand)"></span>${catOf('profiles').tag}</span><h2 id="cat-profiles">Add-ons &amp; social</h2></div></div>
    <div class="mini">${prods('profiles').map(cardHTML).join('')}${prods('smm').map(cardHTML).join('')}</div></div></section>`;
  document.getElementById('catalog').innerHTML=html;
  wireCards();
}

function setRegion(code){REGION=REGIONS.find(r=>r.code===code)||REGIONS[0];
  document.getElementById('regionLabel').textContent=REGION.label;
  document.getElementById('regionFlag').src=FLAG[REGION.code];
  try{localStorage.setItem('gsz_region',code)}catch(e){}
  buildCatalogue();renderRegionMenu();renderDrawerRegion()}
function renderRegionMenu(){document.getElementById('regionMenu').innerHTML=REGIONS.map(r=>`<button data-region="${r.code}" class="${r.code===REGION.code?'on':''}"><img class="flag" src="${FLAG[r.code]}" alt="">${r.label.replace(' · ',' — ')}</button>`).join('')}
function renderDrawerRegion(){document.getElementById('drawerRegion').innerHTML=REGIONS.map(r=>`<button data-region="${r.code}" class="${r.code===REGION.code?'on':''}">${r.cur}</button>`).join('')}

/* ===== HERO ===== */
let cur=0,timer;
function buildHero(){const st=document.getElementById('stage');
  st.innerHTML=SLIDES.map((s,i)=>`<div class="slide${i?'':' on'}" data-i="${i}"><div class="ph" style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;text-align:center;padding:24px;color:#fff;font-family:var(--display);font-weight:800;font-size:clamp(20px,3.2vw,36px);background:radial-gradient(120% 100% at 22% 0%, ${COLOR[s.key]||'#2a7bff'}, transparent 60%),linear-gradient(160deg,#121838,#0a0e22)">${s.title}</div><picture>${s.mobile?`<source media="(max-width:720px)" srcset="/static/img/${s.mobile}">`:''}<img src="/static/img/${s.desktop||''}" alt="${s.title}" ${i?'loading="lazy"':'fetchpriority="high"'} onerror="this.closest('picture').remove()"></picture></div>`).join('')
   +`<button class="arrow prev" aria-label="Previous"><svg class="ic" viewBox="0 0 24 24" style="stroke:#fff"><path d="m15 6-6 6 6 6"/></svg></button>
     <button class="arrow next" aria-label="Next"><svg class="ic" viewBox="0 0 24 24" style="stroke:#fff"><path d="m9 6 6 6-6 6"/></svg></button>
     <div class="dots">${SLIDES.map((s,i)=>`<button data-i="${i}" class="${i?'':'on'}" aria-label="${s.title}"></button>`).join('')}</div>`;
  st.querySelector('.prev').onclick=()=>go(cur-1);st.querySelector('.next').onclick=()=>go(cur+1);
  st.querySelectorAll('.dots button').forEach(b=>b.onclick=()=>go(+b.dataset.i));
  updateAction();start();}
function go(i){const n=SLIDES.length;cur=(i+n)%n;
  document.querySelectorAll('.slide').forEach((s,k)=>s.classList.toggle('on',k===cur));
  document.querySelectorAll('.dots button').forEach((d,k)=>d.classList.toggle('on',k===cur));
  updateAction();start()}
function updateAction(){const s=SLIDES[cur];document.getElementById('abTitle').textContent=s.title;
  const b=document.getElementById('abBtn');b.textContent=s.btn;b.dataset.scroll=s.target}
function start(){clearInterval(timer);timer=setInterval(()=>go(cur+1),6000)}

/* hero 3D parallax */
function heroParallax(){const wrap=document.getElementById('stageWrap'),st=document.getElementById('stage');
  if(matchMedia('(prefers-reduced-motion:reduce)').matches||matchMedia('(max-width:860px)').matches)return;
  wrap.addEventListener('pointermove',e=>{const r=wrap.getBoundingClientRect();
    const x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;
    st.style.transform=`rotateY(${x*3.2}deg) rotateX(${-y*3.2}deg)`;
    const img=document.querySelector('.slide.on img');if(img)img.style.transform=`scale(1.05) translate(${-x*14}px,${-y*10}px)`});
  wrap.addEventListener('pointerleave',()=>{st.style.transform='';const img=document.querySelector('.slide.on img');if(img)img.style.transform=''});}

/* ===== card 3D tilt ===== */
function wireTilt(){if(matchMedia('(pointer:coarse)').matches)return;
  document.querySelectorAll('.thumb[data-tilt]').forEach(t=>{
    t.addEventListener('pointermove',e=>{const r=t.getBoundingClientRect();
      const x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;
      t.style.transform=`perspective(680px) rotateY(${x*7}deg) rotateX(${-y*7}deg)`});
    t.addEventListener('pointerleave',()=>t.style.transform='')})}

/* ===== reviews ===== */
const REVIEWS=(D.reviews||[]).map(r=>({n:r.author,t:r.location,s:r.stars,x:r.body}));
const star='<svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg>';
function buildReviews(){document.getElementById('tpStars').innerHTML=star.repeat(5);
  document.getElementById('revCards').innerHTML=REVIEWS.map(r=>`<div class="rev"><div class="rev-stars">${star.repeat(r.s)}</div>
    <p>${r.x}</p><div class="who"><span class="av">${r.n.split(' ').map(w=>w[0]).join('')}</span><div><b>${r.n}</b><span>${r.t}</span></div></div></div>`).join('')}

/* ===== search ===== */
function openSearch(){const o=document.getElementById('searchOv');o.classList.add('on');const i=document.getElementById('searchInput');i.value='';runSearch('');setTimeout(()=>i.focus(),40)}
function closeSearch(){document.getElementById('searchOv').classList.remove('on')}
function runSearch(q){q=q.trim().toLowerCase();
  const list=q?P.filter(p=>(p.name+' '+p.plan+' '+p.cat+' '+p.desc).toLowerCase().includes(q)).slice(0,10):P.slice(0,6);
  const el=document.getElementById('searchRes');
  if(q&&!list.length){el.innerHTML='<div class="search-empty">No products match “'+q+'”.</div>';return}
  el.innerHTML=(q?'':'<div class="search-lbl">Popular</div>')+list.map(p=>{const c=catOf(p.cat),m=money(p.price);
    return `<button class="sres" data-name="${p.name}" data-plan="${p.plan}"><span class="sq" style="--g1:${c.g1}">${initials(p.name)}</span>
      <span class="si"><b>${p.name}</b><span>${p.plan} · ${c.name}</span></span><span class="sp tnum">${m.cur} ${m.val}</span></button>`}).join('');
  el.querySelectorAll('.sres').forEach(b=>b.onclick=()=>{closeSearch();toast(`“${b.dataset.name}” product page — building next.`)})}

/* ===== toss ===== */
let tossTimer;
function showToss(){const p=P[Math.floor(Math.random()*P.length)],c=catOf(p.cat),el=document.getElementById('toss'),mins=1+Math.floor(Math.random()*9);
  el.innerHTML=`<span class="tq" style="--g1:${c.g1}">${initials(p.name)}</span><span class="ti2"><span class="t1"><span class="d"></span>New order</span>
    <b>${p.name}</b><span>${p.plan} · ${mins} min ago</span></span><span class="tx"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12"/></svg></span>`;
  el.dataset.name=p.name;el.classList.add('on');clearTimeout(tossTimer);tossTimer=setTimeout(()=>el.classList.remove('on'),5200)}
function startToss(){setTimeout(function loop(){showToss();setTimeout(loop,13000+Math.random()*9000)},5000)}

/* ===== toast + wiring ===== */
let toastT;
function toast(m){const t=document.getElementById('toast');t.textContent=m;t.classList.add('on');clearTimeout(toastT);toastT=setTimeout(()=>t.classList.remove('on'),2600)}
function wireCards(){document.querySelectorAll('.card[data-name],.feat[data-name]').forEach(c=>c.onclick=()=>toast(`“${c.dataset.name} — ${c.dataset.plan}” product page — building next.`));wireTilt()}
function smoothTo(id){const el=document.getElementById(id);if(el)window.scrollTo({top:el.getBoundingClientRect().top+scrollY-96,behavior:'smooth'})}
function openDrawer(){document.getElementById('drawer').classList.add('on');document.getElementById('scrim').classList.add('on')}
function closeDrawer(){document.getElementById('drawer').classList.remove('on');document.getElementById('scrim').classList.remove('on')}
function buildDrawerCats(){document.getElementById('drawerCats').innerHTML=CATS.slice(0,6).map(c=>`<button class="dcat" data-scroll="cat-${c.id}" style="--g1:${c.g1}"><span>${iw(c.glyph)}</span><span><b>${c.name}</b><span style="display:block">${c.tag}</span></span></button>`).join('')}
function iw(g){return `<svg class="ic" viewBox="0 0 24 24" style="stroke:#fff">${ICON[g]}</svg>`}
function buildMarquee(){const items=['Instant automated delivery','Pay in PKR, USD or crypto','Verified before we deliver','Real WhatsApp support','Invoices on every order'];
  const row=items.map(t=>`<li>${iw('shield').replace('class="ic"','class="ic ic-sm"')}${t}</li>`).join('');document.getElementById('marqueeList').innerHTML=row+row}

function wireGlobal(){
  document.addEventListener('click',e=>{
    const sc=e.target.closest('[data-scroll]');if(sc){e.preventDefault();smoothTo(sc.dataset.scroll);closeDrawer();return}
    const tt=e.target.closest('[data-toast]');if(tt){e.preventDefault();toast(tt.dataset.toast);return}
    const rb=e.target.closest('[data-region]');if(rb){setRegion(rb.dataset.region);document.getElementById('regionMenu').classList.remove('on');return}});
  const hd=document.getElementById('hd');addEventListener('scroll',()=>hd.classList.toggle('scrolled',scrollY>8),{passive:true});
  document.getElementById('searchBtn').onclick=openSearch;
  document.getElementById('searchInput').addEventListener('input',e=>runSearch(e.target.value));
  document.getElementById('searchOv').addEventListener('click',e=>{if(e.target.id==='searchOv')closeSearch()});
  addEventListener('keydown',e=>{if(e.key==='Escape'){closeSearch();document.getElementById('regionMenu').classList.remove('on')}if(e.key==='k'&&(e.metaKey||e.ctrlKey)){e.preventDefault();openSearch()}});
  const rBtn=document.getElementById('regionBtn');rBtn.onclick=e=>{e.stopPropagation();document.getElementById('regionMenu').classList.toggle('on')};
  document.addEventListener('click',e=>{if(!e.target.closest('.pos-rel'))document.getElementById('regionMenu').classList.remove('on')});
  document.getElementById('offerX').onclick=()=>document.getElementById('offerBar').style.display='none';
  document.getElementById('codeChip').onclick=()=>{try{navigator.clipboard.writeText('GALAXY10')}catch(e){}toast('Code GALAXY10 copied — demo code, set yours in admin.')};
  document.getElementById('burger').onclick=openDrawer;document.getElementById('drawerX').onclick=closeDrawer;document.getElementById('scrim').onclick=closeDrawer;
  const toss=document.getElementById('toss');toss.onclick=e=>{if(e.target.closest('.tx')){toss.classList.remove('on');return}toast(`“${toss.dataset.name}” product page — building next.`)};
}

/* ===== brand aurora ===== */
function aurora(){const cv=document.getElementById('aura'),ctx=cv.getContext('2d');let w,h,raf;
  const blobs=[{c:'138,43,255'},{c:'42,123,255'},{c:'23,203,240'},{c:'194,59,255'}].map((b,i)=>({...b,
    x:Math.random(),y:Math.random()*.6,r:0,vx:(Math.random()-.5)*.00018,vy:(Math.random()-.5)*.00014,ph:i}));
  function size(){w=cv.width=innerWidth;h=cv.height=Math.min(innerHeight*1.1, 1100);cv.style.height=h+'px'}
  function draw(t){ctx.clearRect(0,0,w,h);ctx.globalCompositeOperation='lighter';
    blobs.forEach(b=>{b.x+=b.vx;b.y+=b.vy;if(b.x<-.1||b.x>1.1)b.vx*=-1;if(b.y<-.1||b.y>.8)b.vy*=-1;
      const cx=b.x*w,cy=b.y*h+Math.sin(t/4000+b.ph)*18,rad=Math.max(w,h)*.42;
      const g=ctx.createRadialGradient(cx,cy,0,cx,cy,rad);
      g.addColorStop(0,`rgba(${b.c},.20)`);g.addColorStop(1,`rgba(${b.c},0)`);
      ctx.fillStyle=g;ctx.beginPath();ctx.arc(cx,cy,rad,0,7);ctx.fill()});
    raf=requestAnimationFrame(draw)}
  size();addEventListener('resize',size);
  if(matchMedia('(prefers-reduced-motion:reduce)').matches){draw(0);return}
  raf=requestAnimationFrame(draw)}

/* ===== boot ===== */
(function(){
  try{const r=localStorage.getItem('gsz_region');if(r)REGION=REGIONS.find(x=>x.code===r)||REGIONS[0]}catch(e){}
  document.getElementById('regionLabel').textContent=REGION.label;
  document.getElementById('regionFlag').src=FLAG[REGION.code];
  aurora();buildMarquee();buildHero();heroParallax();buildCatalogue();buildReviews();buildDrawerCats();
  renderRegionMenu();renderDrawerRegion();wireGlobal();startToss();
})();
GSZ_JS_EOF
cat > "$APP/server.js" <<'GSZ_SRV_EOF'
require('dotenv').config();
const path = require('path');
const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const session = require('express-session');
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  max: 10
});

const app = express();
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
app.use(compression());
app.use(morgan('tiny'));
app.use('/static', express.static(path.join(__dirname, 'public'), { maxAge: '7d' }));
app.use(session({ secret: process.env.SESSION_SECRET, resave: false, saveUninitialized: false }));

// Build the full homepage data object from the database.
async function homeData() {
  const cats = (await pool.query(
    'SELECT slug, name, tag, glyph FROM categories WHERE active ORDER BY sort, id'
  )).rows;

  const products = (await pool.query(
    `SELECT p.slug, c.slug AS cat, p.name, p.short_desc AS desc, p.delivery,
            pl.label AS plan, pl.price_pkr AS price, pl.old_pkr AS old
     FROM products p
     JOIN categories c ON c.id = p.category_id
     LEFT JOIN LATERAL (
       SELECT label, price_pkr, old_pkr FROM product_plans
       WHERE product_id = p.id ORDER BY sort, id LIMIT 1
     ) pl ON true
     WHERE p.active AND NOT p.hidden
     ORDER BY p.sort, p.id`
  )).rows.map(r => ({
    slug: r.slug, cat: r.cat, name: r.name, plan: r.plan || '',
    price: Number(r.price || 0), old: Number(r.old || 0),
    desc: r.desc || '', delivery: r.delivery || ''
  }));

  const banners = (await pool.query(
    'SELECT category_slug, device, filename, title FROM banners WHERE active ORDER BY sort, id'
  )).rows;

  const reviews = (await pool.query(
    'SELECT author, location, stars, body FROM reviews WHERE approved ORDER BY id DESC LIMIT 12'
  )).rows;

  const settings = {};
  (await pool.query('SELECT key, value FROM settings')).rows.forEach(r => { settings[r.key] = r.value; });

  return { cats, products, banners, reviews, settings };
}

app.get('/health', async (req, res) => {
  try {
    const c = await pool.query('SELECT count(*)::int AS n FROM categories');
    const p = await pool.query('SELECT count(*)::int AS n FROM products');
    const b = await pool.query('SELECT count(*)::int AS n FROM banners');
    res.json({ ok: true, categories: c.rows[0].n, products: p.rows[0].n, banners: b.rows[0].n });
  } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
});

app.get('/', async (req, res) => {
  try {
    const data = await homeData();
    const siteName = data.settings.site_name || 'Galaxy Subz × Zayron';
    const dataJson = JSON.stringify(data).replace(/</g, '\\u003c');
    res.render('home', { siteName, dataJson });
  } catch (e) {
    res.status(500).send('Home render error: ' + e.message);
  }
});

const PORT = process.env.PORT || 3600;
app.listen(PORT, '0.0.0.0', () => console.log('[gsz] listening on ' + PORT));
GSZ_SRV_EOF

node --check "$APP/server.js"
node --check "$APP/public/js/app.js"
echo "[ok] server.js + app.js parse clean"
pm2 restart gsz --update-env >/dev/null
sleep 1.6
HTML=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
if echo "$HTML" | grep -q "Prime Video" && echo "$HTML" | grep -q "window.__DATA"; then
  echo "[ok] homepage renders ($(printf %s "$HTML" | wc -c) bytes, real catalogue present)"
else
  echo "HOMEPAGE CHECK FAILED — rolling back server.js"
  LAST=$(ls -t "$APP"/server.js.bak-step2.* | head -1); cp -a "$LAST" "$APP/server.js"
  pm2 restart gsz >/dev/null; pm2 logs gsz --lines 20 --nostream || true; exit 1
fi
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi "Status: active"; then
  ufw allow "$PORT"/tcp >/dev/null 2>&1 || true
  echo "[ok] opened port $PORT in ufw"
fi
echo "============================================================"
echo " STEP 2 COMPLETE — homepage is live and database-driven"
echo "   view it:  http://143.198.209.68:$PORT/"
echo "   (banners + logo show branded placeholders until Step 3 upload)"
echo "============================================================"
