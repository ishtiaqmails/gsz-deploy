#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 14: home banners removed + hero breathing
#  RUN: cd /opt/gsz-deploy && git pull && bash step14.sh
#  - REMOVES category banners from the HOME page (IPTV band + showcase
#    banner). Home now shows, per category: heading + a few product
#    cards + "View all". Banners stay ONLY on each category's own page.
#  - HERO gets breathing room from the screen edges + rounded corners
#    (applies to category-page banners too — shared .hero-stage).
#  - Re-applies Step 13 (it rolled back on a buggy check):
#      * product.ejs "&amp;" double-escape fix
#      * header search no longer squeezed on wide screens
#  - Removes now-unused CSS (.iptv-band / .showcase / .show-banner).
#  - Bumps asset version to v=14.
#  - FIXED health check: no "curl | grep -q" under pipefail (that
#    false-failed Step 13). Uses captured bodies + here-strings.
#  Touches: app.css, views/home.ejs, views/product.ejs, partials (?v).
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views" ] || { echo "ABORT: $APP/views not found"; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"; : "${DB_USER:?}"; : "${DB_NAME:?}"; : "${DB_PASS:?}"
echo "== Galaxy Subz x Zayron — Step 14 (home de-banner + hero breathing) · port $PORT =="
ts=$(date +%s)
PSQL(){ PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" "$@"; }

cp -a "$APP/public/css/app.css"              "$APP/public/css/app.css.bak-step14.$ts"
cp -a "$APP/views/home.ejs"                  "$APP/views/home.ejs.bak-step14.$ts"
cp -a "$APP/views/product.ejs"               "$APP/views/product.ejs.bak-step14.$ts"
cp -a "$APP/views/partials/store_top.ejs"    "$APP/views/partials/store_top.ejs.bak-step14.$ts"
cp -a "$APP/views/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs.bak-step14.$ts"
restore(){
  echo ">> rolling back Step 14"
  cp -a "$APP/public/css/app.css.bak-step14.$ts"              "$APP/public/css/app.css"
  cp -a "$APP/views/home.ejs.bak-step14.$ts"                  "$APP/views/home.ejs"
  cp -a "$APP/views/product.ejs.bak-step14.$ts"              "$APP/views/product.ejs"
  cp -a "$APP/views/partials/store_top.ejs.bak-step14.$ts"    "$APP/views/partials/store_top.ejs"
  cp -a "$APP/views/partials/store_bottom.ejs.bak-step14.$ts" "$APP/views/partials/store_bottom.ejs"
  pm2 restart gsz >/dev/null 2>&1 || true
}
cat > "$APP/public/css/app.css" <<'GSZ_CSS_EOF'
/* ============================================================
   GALAXY SUBZ × ZAYRON — storefront design system (v2)
   Light, neutral-led, restrained brand accents. One system.
   ============================================================ */
:root{
  --paper:#fbfbfd; --surface:#ffffff; --ink:#0e1430; --muted:#6b7391;
  --line:#eceef5; --line-2:#e3e6f1;
  --v:#7a2bff; --b:#2a6cff; --c:#19c6ee;
  --brand:linear-gradient(100deg,#7a2bff,#2a6cff 55%,#19c6ee);
  --ink-soft:#2a3152; --wash:#f4f6fb;
  --ok:#12b26a; --warn:#e8a33d;
  --display:'Bricolage Grotesque',system-ui,sans-serif;
  --body:'Hanken Grotesk',system-ui,'Segoe UI',sans-serif;
  --wrap:1200px; --gut:clamp(16px,4vw,40px);
  --r:16px; --r-sm:11px; --r-lg:22px;
  --shadow:0 1px 2px rgba(14,20,48,.04),0 14px 34px -22px rgba(14,20,48,.26);
  --shadow-lg:0 2px 6px rgba(14,20,48,.05),0 30px 60px -30px rgba(14,20,48,.34);
}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--paper);color:var(--ink);font-family:var(--body);
  font-size:16px;line-height:1.5;-webkit-font-smoothing:antialiased}
a{color:inherit;text-decoration:none}
img{max-width:100%;display:block}
ul{margin:0;padding:0;list-style:none}
button{font-family:inherit}
.wrap{max-width:var(--wrap);margin:0 auto;padding:0 var(--gut)}
.ic{width:22px;height:22px;stroke:currentColor;fill:none;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round}
.ic-sm{width:17px;height:17px}
.tnum{font-variant-numeric:tabular-nums}
.grad-text{background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent}

/* ---- buttons ---- */
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;
  font-weight:600;font-size:15px;border:0;border-radius:12px;padding:12px 20px;cursor:pointer;
  transition:transform .15s ease,box-shadow .15s ease,background .15s ease;white-space:nowrap}
.btn-primary{background:var(--brand);color:#fff;box-shadow:0 12px 26px -12px rgba(42,108,255,.85)}
.btn-primary:hover{transform:translateY(-1px);box-shadow:0 16px 30px -12px rgba(42,108,255,.95)}
.btn-dark{background:var(--ink);color:#fff}
.btn-dark:hover{transform:translateY(-1px)}
.btn-ghost{background:var(--surface);color:var(--ink);box-shadow:inset 0 0 0 1px var(--line-2)}
.btn-ghost:hover{box-shadow:inset 0 0 0 1.5px var(--b);color:var(--b)}
.btn-wa{background:#1fb457;color:#fff}
.btn-wa:hover{background:#19a04d;transform:translateY(-1px)}
.btn-lg{padding:15px 26px;font-size:16px;border-radius:14px}

/* ---- offer bar (no close button) ---- */
.offer{background:var(--ink);color:#fff;font-size:13.5px;overflow:hidden}
.offer-in{display:flex;align-items:center;gap:16px;height:40px;max-width:var(--wrap);margin:0 auto;padding:0 var(--gut)}
.marquee{flex:1;overflow:hidden;mask:linear-gradient(90deg,transparent,#000 6%,#000 94%,transparent)}
.marquee ul{display:flex;gap:40px;width:max-content;animation:marq 32s linear infinite}
.marquee li{display:flex;align-items:center;gap:8px;color:#cdd3ea;white-space:nowrap}
.marquee li svg{color:var(--c)}
@keyframes marq{to{transform:translateX(-50%)}}
.code-chip{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.1);color:#fff;
  border:0;border-radius:999px;padding:6px 13px;font-size:12.5px;font-weight:600;cursor:pointer;white-space:nowrap}
.code-chip b{letter-spacing:.04em}
.code-chip:hover{background:rgba(255,255,255,.18)}

/* ---- header ---- */
.hd{position:sticky;top:0;z-index:50;background:rgba(251,251,253,.86);backdrop-filter:blur(14px);
  border-bottom:1px solid transparent;transition:border-color .2s,box-shadow .2s}
.hd.scrolled{border-color:var(--line);box-shadow:0 10px 30px -24px rgba(14,20,48,.4)}
.hd-in{display:flex;align-items:center;gap:20px;height:76px}
.brand{display:flex;align-items:center;gap:9px;flex:none}
.brand img{height:40px;width:auto}
.wordmark{font-family:var(--display);font-weight:800;font-size:21px;letter-spacing:-.02em}
.nav{display:flex;align-items:center;gap:4px}
.nav a{padding:9px 13px;border-radius:9px;font-weight:600;font-size:15px;color:var(--ink-soft);transition:.15s}
.nav a:hover{background:var(--wash);color:var(--ink)}
.hd-search{flex:1;max-width:460px;position:relative}
.hd-search input{width:100%;height:44px;border:1px solid var(--line-2);border-radius:12px;background:var(--surface);
  padding:0 14px 0 42px;font-size:14.5px;font-family:inherit;color:var(--ink)}
.hd-search input:focus{outline:2px solid var(--b);outline-offset:1px;border-color:transparent}
.hd-search .si{position:absolute;left:13px;top:50%;transform:translateY(-50%);color:var(--muted)}
.hd-sp{display:none}
.hd-tools{display:flex;align-items:center;gap:10px;flex:none;margin-left:auto}
.region{display:inline-flex;align-items:center;gap:7px;background:var(--surface);border:1px solid var(--line-2);
  border-radius:11px;padding:8px 11px;font-weight:600;font-size:13.5px;cursor:pointer;color:var(--ink)}
.region:hover{border-color:var(--b)}
.region .flag{width:18px;height:13px;border-radius:2px;object-fit:cover}
.pos-rel{position:relative}
.rmenu{position:absolute;right:0;top:calc(100% + 8px);background:var(--surface);border:1px solid var(--line);
  border-radius:12px;box-shadow:var(--shadow-lg);padding:6px;min-width:170px;display:none;z-index:60}
.rmenu.on{display:block}
.rmenu button{display:flex;align-items:center;gap:9px;width:100%;border:0;background:none;padding:9px 11px;
  border-radius:8px;font-weight:600;font-size:13.5px;cursor:pointer;color:var(--ink-soft)}
.rmenu button:hover{background:var(--wash)}
.rmenu button.on{color:var(--b)}
.rmenu .flag{width:18px;height:13px;border-radius:2px}
.icon-btn{display:inline-grid;place-items:center;width:44px;height:44px;border-radius:11px;background:var(--surface);
  border:1px solid var(--line-2);color:var(--ink);cursor:pointer;position:relative}
.icon-btn:hover{border-color:var(--b);color:var(--b)}
.burger{display:none}
.hd-wa .label{display:inline}

/* search dropdown (inline, no popup) */
.sresults{position:absolute;left:0;right:0;top:calc(100% + 8px);background:var(--surface);border:1px solid var(--line);
  border-radius:14px;box-shadow:var(--shadow-lg);padding:6px;max-height:min(70vh,440px);overflow:auto;display:none;z-index:70}
.sresults.on{display:block}
.sresult{display:flex;align-items:center;gap:12px;padding:9px 11px;border-radius:10px}
.sresult:hover{background:var(--wash)}
.sresult .th{width:40px;height:40px;border-radius:9px;object-fit:cover;flex:none;background:var(--wash)}
.sresult .nm{font-weight:600;font-size:14px}
.sresult .mt{font-size:12.5px;color:var(--muted)}
.sresult .pr{margin-left:auto;font-weight:700;font-size:13.5px}
.sempty{padding:18px 12px;color:var(--muted);font-size:14px;text-align:center}

/* ---- hero (inset, soft rounded, breathing room from edges) ---- */
.hero{position:relative;width:100%;padding:clamp(12px,1.8vw,22px) var(--gut) 0}
.hero-stage{position:relative;width:100%;max-width:1640px;margin-inline:auto;aspect-ratio:1942/809;overflow:hidden;border-radius:var(--r-lg);background:var(--wash);box-shadow:0 1px 0 var(--line)}
.hslide{position:absolute;inset:0;opacity:0;transition:opacity .7s ease;pointer-events:none}
.hslide.on{opacity:1;pointer-events:auto}
.hslide{display:block}
.hslide img{width:100%;height:100%;object-fit:cover;display:block;will-change:transform}
.hero-dots{position:absolute;right:var(--gut);bottom:18px;display:flex;gap:7px;z-index:3}
.hero-dots button{width:9px;height:9px;border-radius:999px;border:0;background:rgba(255,255,255,.45);cursor:pointer;padding:0}
.hero-dots button.on{background:#fff;width:24px}
.hero-ar{position:absolute;top:50%;transform:translateY(-50%);width:44px;height:44px;border-radius:999px;
  border:0;background:rgba(10,14,34,.42);color:#fff;display:grid;place-items:center;cursor:pointer;z-index:3}
.hero-ar:hover{background:rgba(10,14,34,.7)}
.hero-ar.prev{left:14px}.hero-ar.next{right:14px}
@media(max-width:720px){.hero-stage{aspect-ratio:1536/1024;max-height:78vh}.hero-ar{display:none}}

/* ---- credibility stats ---- */
.stats{border-bottom:1px solid var(--line)}
.stats-in{display:grid;grid-template-columns:repeat(3,1fr);gap:0;padding:26px 0}
.stat{text-align:center;padding:4px 16px;position:relative}
.stat+.stat{border-left:1px solid var(--line)}
.stat b{display:block;font-family:var(--display);font-weight:800;font-size:clamp(26px,3.4vw,38px);letter-spacing:-.02em;line-height:1}
.stat .lbl{display:block;margin-top:7px;color:var(--muted);font-size:13.5px;font-weight:500}
.stat .star{color:#f5b301}
@media(max-width:560px){.stats-in{padding:18px 0}.stat{padding:4px 8px}.stat .lbl{font-size:12px}}

/* ---- section rhythm ---- */
.section{padding:clamp(44px,6vw,78px) 0}
.section.tint{background:var(--wash)}
.sec-head{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;margin-bottom:30px}
.sec-head .eyebrow{display:inline-flex;align-items:center;gap:8px;font-weight:600;font-size:13.5px;color:var(--muted)}
.sec-head .eyebrow .dot{width:8px;height:8px;border-radius:999px;background:var(--brand)}
.sec-head h2{font-family:var(--display);font-weight:800;font-size:clamp(24px,3vw,34px);letter-spacing:-.02em;margin:6px 0 0;line-height:1.05}
.view-all{display:inline-flex;align-items:center;gap:6px;font-weight:600;font-size:14.5px;color:var(--b);flex:none}
.view-all:hover{text-decoration:underline}

/* ---- category grid ---- */
.catgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:14px}
.cat-tile{display:flex;align-items:center;gap:14px;background:var(--surface);border:1px solid var(--line);
  border-radius:var(--r);padding:16px;transform-style:preserve-3d;will-change:transform;
  transition:transform .2s cubic-bezier(.2,.7,.3,1),box-shadow .2s,border-color .2s}
.cat-tile:hover{box-shadow:0 20px 44px -22px rgba(42,108,255,.5);border-color:transparent}
.cat-tile .cg{transition:transform .2s cubic-bezier(.2,.7,.3,1)}
.cat-tile:hover .cg{transform:translateZ(22px) scale(1.05)}
.cat-tile .cg{width:46px;height:46px;border-radius:13px;display:grid;place-items:center;flex:none;color:#fff;
  background:linear-gradient(135deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.cat-tile .cg svg{stroke:#fff}
.cat-tile b{font-family:var(--display);font-weight:700;font-size:16px;letter-spacing:-.01em;display:block}
.cat-tile .n{color:var(--muted);font-size:13px}

/* ---- product grid + cards ---- */
.pgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:18px}
.pgrid.g4{grid-template-columns:repeat(4,1fr)}
@media(max-width:900px){.pgrid.g4{grid-template-columns:repeat(2,1fr)}}
@media(max-width:520px){.pgrid,.pgrid.g4{grid-template-columns:repeat(2,1fr);gap:12px}}
.pcard{position:relative;display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--line);
  border-radius:var(--r);overflow:hidden;transform-style:preserve-3d;will-change:transform;
  transition:transform .2s cubic-bezier(.2,.7,.3,1),box-shadow .25s ease,border-color .2s}
.pcard:hover{box-shadow:0 26px 60px -26px rgba(42,108,255,.55),0 2px 8px rgba(14,20,48,.06);border-color:transparent}
.pcard .pimg,.pcard .pfallback{transition:transform .55s cubic-bezier(.2,.7,.3,1)}
.pcard:hover .pimg,.pcard:hover .pfallback{transform:scale(1.07)}
.pcard::after{content:"";position:absolute;top:0;left:-60%;width:42%;height:100%;z-index:3;pointer-events:none;
  background:linear-gradient(100deg,transparent,rgba(255,255,255,.4),transparent);transform:skewX(-18deg);opacity:0}
.pcard:hover::after{opacity:1;animation:shine .9s ease forwards}
@keyframes shine{from{left:-60%}to{left:130%}}
.pcard .pimg{aspect-ratio:1/1;width:100%;object-fit:cover;background:var(--wash)}
.pcard .pfallback{aspect-ratio:1/1;width:100%;display:grid;place-items:center;position:relative;overflow:hidden;
  background:linear-gradient(145deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.pcard .pfallback span{font-family:var(--display);font-weight:800;color:#fff;font-size:30px;letter-spacing:-.02em;
  opacity:.95;text-align:center;padding:0 14px;line-height:1.05}
.pcard .pbody{padding:14px 15px 16px;display:flex;flex-direction:column;gap:4px;flex:1}
.pcard .pname{font-family:var(--display);font-weight:700;font-size:16px;letter-spacing:-.01em;line-height:1.2}
.pcard .pdesc{color:var(--muted);font-size:13.5px;line-height:1.45;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.pcard .pfoot{margin-top:auto;padding-top:12px;display:flex;align-items:baseline;gap:6px}
.pcard .pfrom{color:var(--muted);font-size:12px;font-weight:500}
.pcard .pprice{font-family:var(--display);font-weight:800;font-size:17px;letter-spacing:-.01em}

/* ---- reviews ---- */
.rev-grid{display:grid;grid-template-columns:300px 1fr;gap:24px}
@media(max-width:820px){.rev-grid{grid-template-columns:1fr}}
.tp-card{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:26px;align-self:start}
.tp-score{display:flex;align-items:baseline;gap:6px}
.tp-score b{font-family:var(--display);font-weight:800;font-size:46px;letter-spacing:-.02em;line-height:1}
.tp-score span{color:var(--muted);font-weight:600}
.stars{display:flex;gap:3px;margin:12px 0 10px;color:#f5b301}
.stars svg{width:20px;height:20px;fill:currentColor;stroke:none}
.tp-sub{color:var(--muted);font-size:13.5px}
.tp-logo{display:flex;align-items:center;gap:7px;margin-top:16px;font-weight:700;font-size:15px}
.tp-logo svg{width:20px;height:20px;fill:#12b26a;stroke:none}
.rev-cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:16px}
.rev{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:18px}
.rev .rs{display:flex;gap:2px;color:#f5b301;margin-bottom:9px}
.rev .rs svg{width:15px;height:15px;fill:currentColor;stroke:none}
.rev p{margin:0 0 14px;font-size:14.5px;line-height:1.5;color:var(--ink-soft)}
.rev .who{display:flex;align-items:center;gap:10px}
.rev .av{width:34px;height:34px;border-radius:999px;display:grid;place-items:center;color:#fff;font-weight:700;font-size:13px;background:var(--brand)}
.rev .who b{font-size:13.5px;display:block}
.rev .who span{font-size:12px;color:var(--muted)}

/* ---- brand family ---- */
.house{border-top:1px solid var(--line);border-bottom:1px solid var(--line);background:var(--surface)}
.house-in{display:flex;align-items:center;gap:22px;flex-wrap:wrap;padding:22px 0}
.house .lbl{display:inline-flex;align-items:center;gap:8px;color:var(--muted);font-size:13.5px;font-weight:600}
.house .lbl svg{color:var(--ok)}
.brands{display:flex;gap:10px;flex-wrap:wrap}
.brands a{font-family:var(--display);font-weight:700;font-size:15px;color:var(--ink-soft);
  padding:7px 14px;border-radius:999px;background:var(--wash)}
.brands a:hover{color:var(--b)}

/* ---- footer ---- */
.ft{background:var(--ink);color:#c7cdea;padding:56px 0 30px}
.ft-top{display:grid;grid-template-columns:1.6fr 1fr 1fr 1fr;gap:34px}
@media(max-width:820px){.ft-top{grid-template-columns:1fr 1fr}}
@media(max-width:520px){.ft-top{grid-template-columns:1fr}}
.ft-brand img{height:38px;margin-bottom:12px}
.ft-brand .wordmark{color:#fff}
.ft-brand p{font-size:14px;line-height:1.55;max-width:38ch;margin:10px 0 16px}
.social{display:flex;gap:10px}
.social a{width:38px;height:38px;border-radius:10px;display:grid;place-items:center;background:rgba(255,255,255,.07);color:#fff}
.social a:hover{background:var(--brand)}
.ft-col h4{color:#fff;font-family:var(--display);font-size:14px;font-weight:700;margin:0 0 14px;letter-spacing:.01em}
.ft-col a{display:block;font-size:14px;padding:5px 0;color:#aab2d6}
.ft-col a:hover{color:#fff}
.ft-bottom{display:flex;align-items:center;justify-content:space-between;gap:14px;flex-wrap:wrap;
  margin-top:36px;padding-top:22px;border-top:1px solid rgba(255,255,255,.1);font-size:13px}
.pays{display:flex;gap:8px;flex-wrap:wrap}
.pay{background:rgba(255,255,255,.07);border-radius:7px;padding:5px 11px;font-size:12.5px;font-weight:600;color:#cdd3ea}

/* ---- drawer (mobile) ---- */
.scrim-el{position:fixed;inset:0;background:rgba(10,14,34,.5);opacity:0;pointer-events:none;transition:.25s;z-index:80}
.scrim-el.on{opacity:1;pointer-events:auto}
.drawer{position:fixed;top:0;right:0;bottom:0;width:min(86vw,340px);background:var(--surface);z-index:90;
  transform:translateX(100%);transition:transform .28s ease;display:flex;flex-direction:column;padding:18px}
.drawer.on{transform:none}
.drawer-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:12px}
.drawer-top img{height:34px}
.drawer-cats{display:flex;flex-direction:column;gap:4px;margin:8px 0}
.dcat{display:flex;align-items:center;gap:12px;border:0;background:none;padding:11px 10px;border-radius:11px;cursor:pointer;text-align:left;color:var(--ink)}
.dcat:hover{background:var(--wash)}
.dcat .cg{width:38px;height:38px;border-radius:10px;display:grid;place-items:center;color:#fff;flex:none;
  background:linear-gradient(135deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.dcat b{font-weight:700;font-size:14.5px}
.dcat .n{font-size:12px;color:var(--muted)}
.drawer-foot{margin-top:auto;padding-top:14px;border-top:1px solid var(--line);display:flex;flex-direction:column;gap:12px}
.drawer-region{display:flex;gap:8px}
.drawer-region button{flex:1;border:1px solid var(--line-2);background:var(--surface);border-radius:9px;padding:9px;font-weight:600;cursor:pointer;color:var(--ink-soft)}
.drawer-region button.on{border-color:var(--b);color:var(--b)}

/* ---- toss (social proof popup) ---- */
.toss{position:fixed;left:18px;bottom:18px;z-index:70;display:flex;align-items:center;gap:12px;
  background:var(--surface);border:1px solid var(--line);border-radius:14px;box-shadow:var(--shadow-lg);
  padding:11px 14px;max-width:320px;cursor:pointer;transform:translateY(140%);transition:transform .4s cubic-bezier(.2,.7,.3,1);text-align:left}
.toss.on{transform:none}
.toss .tt{width:40px;height:40px;border-radius:10px;display:grid;place-items:center;color:#fff;flex:none;background:var(--brand)}
.toss .tb b{font-size:13.5px;display:block}
.toss .tb span{font-size:12px;color:var(--muted)}
.toss .tx{position:absolute;top:-8px;right:-8px;width:22px;height:22px;border-radius:999px;background:var(--ink);
  color:#fff;border:0;display:grid;place-items:center;cursor:pointer;font-size:12px}

/* ---- toast ---- */
.toast{position:fixed;left:50%;bottom:26px;transform:translateX(-50%) translateY(140%);z-index:95;
  background:var(--ink);color:#fff;border-radius:12px;padding:12px 18px;font-size:14px;font-weight:500;
  box-shadow:var(--shadow-lg);transition:transform .3s;max-width:90vw}
.toast.on{transform:translateX(-50%)}

/* ---- responsive header ---- */
@media(max-width:1040px){
  .nav{display:none}
  .hd-search{max-width:none}
}
@media(max-width:760px){
  .hd-in{height:auto;min-height:64px;gap:10px;flex-wrap:wrap;padding:10px 0}
  .hd-search{display:block;order:5;flex-basis:100%;max-width:none}
  .hd-sp{display:none}
  .hd-wa .label{display:none}
  .hd-wa{padding:0;width:44px;height:44px;border-radius:11px}
  .burger{display:inline-grid}
  .region{display:none}
}

/* ============================================================
   MOTION & DEPTH — scroll reveal, button shine
   (3D tilt + hero parallax handled in app.js; reduced-motion safe)
   ============================================================ */
.gsz-js .reveal{opacity:0;transform:translateY(26px);transition:opacity .7s ease,transform .7s cubic-bezier(.2,.7,.3,1)}
.gsz-js .reveal.in{opacity:1;transform:none}
.btn-primary{position:relative;overflow:hidden}
.btn-primary::after{content:"";position:absolute;top:0;left:-70%;width:40%;height:100%;pointer-events:none;
  background:linear-gradient(100deg,transparent,rgba(255,255,255,.4),transparent);transform:skewX(-18deg);opacity:0}
.btn-primary:hover::after{opacity:1;animation:shine .8s ease forwards}
@media(prefers-reduced-motion:reduce){
  .reveal{opacity:1;transform:none;transition:none}
}
@media(prefers-reduced-motion:reduce){
  *{animation-duration:.001ms !important;transition-duration:.001ms !important}
  .marquee ul{animation:none}
}

/* ============================================================
   PRODUCT PAGE (PDP)
   ============================================================ */
.pdp{padding:clamp(26px,4vw,46px) 0}
.pdp-top{display:grid;grid-template-columns:1fr 1fr;gap:clamp(22px,4vw,48px);align-items:start}
@media(max-width:860px){.pdp-top{grid-template-columns:1fr}}
.pdp-media{position:relative;border-radius:var(--r-lg);overflow:hidden;aspect-ratio:1/1;background:var(--wash);
  box-shadow:var(--shadow-lg);transform-style:preserve-3d;will-change:transform;transition:transform .2s cubic-bezier(.2,.7,.3,1)}
.pdp-media img{width:100%;height:100%;object-fit:cover}
.pdp-media .pf{width:100%;height:100%;display:grid;place-items:center;color:#fff;font-family:var(--display);
  font-weight:800;font-size:clamp(28px,5vw,46px);letter-spacing:-.02em;text-align:center;padding:24px;line-height:1.05;
  background:linear-gradient(145deg,var(--g1,#2a6cff),var(--g2,#19c6ee))}
.pdp-info .crumbs{font-size:13px;color:var(--muted);margin-bottom:12px}
.pdp-info .crumbs a{color:var(--muted)}
.pdp-info .crumbs a:hover{color:var(--b)}
.pdp-info h1{font-family:var(--display);font-weight:800;font-size:clamp(28px,4vw,42px);letter-spacing:-.02em;margin:0 0 12px;line-height:1.04}
.pdp-meta{display:flex;align-items:center;gap:16px;color:var(--muted);font-size:14px;margin-bottom:18px;flex-wrap:wrap}
.pdp-meta .rt{display:inline-flex;align-items:center;gap:5px;color:#1d2340;font-weight:700}
.pdp-meta .rt .star{color:#f5b301}
.pdp-meta .chip{display:inline-flex;align-items:center;gap:6px;background:var(--wash);border-radius:999px;padding:5px 11px;font-size:12.5px;font-weight:600;color:var(--ink-soft)}
.pdp-lead{font-size:15.5px;color:var(--ink-soft);line-height:1.6;margin:0 0 24px;max-width:52ch}
.plans{display:flex;flex-direction:column;gap:10px;margin-bottom:22px}
.plan{display:flex;align-items:center;gap:14px;border:1.5px solid var(--line-2);border-radius:13px;padding:14px 16px;cursor:pointer;background:var(--surface);transition:.15s}
.plan:hover{border-color:var(--b)}
.plan.sel{border-color:var(--b);box-shadow:0 0 0 3px rgba(42,108,255,.12)}
.plan .rdo{width:20px;height:20px;border-radius:50%;border:2px solid var(--line-2);flex:none;display:grid;place-items:center}
.plan.sel .rdo:after{content:"";width:10px;height:10px;border-radius:50%;background:var(--b)}
.plan .pl{font-weight:600;font-size:15px;flex:1}
.plan .pp{font-family:var(--display);font-weight:800;font-size:17px;white-space:nowrap}
.plan .pp .was{font-size:12.5px;color:var(--muted);text-decoration:line-through;font-weight:500;margin-right:6px}
.buyrow{display:flex;gap:12px;flex-wrap:wrap}
.buyrow .btn{flex:1;min-width:150px}
.tchips{display:flex;gap:9px;flex-wrap:wrap;margin-top:20px}
.tchips span{display:inline-flex;align-items:center;gap:7px;font-size:12.5px;color:var(--ink-soft);background:var(--wash);border-radius:999px;padding:8px 13px}
.tchips svg{color:var(--b)}
.pdp-sec{padding:clamp(30px,4vw,48px) 0;border-top:1px solid var(--line)}
.pdp-sec h2{font-family:var(--display);font-weight:800;font-size:clamp(20px,2.4vw,26px);letter-spacing:-.01em;margin:0 0 18px}
.longdesc{color:var(--ink-soft);line-height:1.75;max-width:72ch;white-space:pre-wrap;font-size:15.5px}
.faq details{border:1px solid var(--line);border-radius:12px;margin-bottom:10px;background:var(--surface);overflow:hidden}
.faq summary{padding:15px 18px;font-weight:600;font-size:15px;cursor:pointer;list-style:none;display:flex;justify-content:space-between;align-items:center;gap:14px}
.faq summary::-webkit-details-marker{display:none}
.faq summary::after{content:"+";font-size:22px;color:var(--muted);line-height:1}
.faq details[open] summary::after{content:"\2013"}
.faq p{margin:0;padding:0 18px 16px;color:var(--ink-soft);line-height:1.65}

GSZ_CSS_EOF

cat > "$APP/views/home.ejs" <<'GSZ_HOME_EOF'
<%- include('partials/store_top') %>
<%
function esc(s){return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
var catBy={}; cats.forEach(function(c){catBy[c.slug]=c;});
function card(p){
  var cat=catBy[p.cat]||{};
  var img=p.image
    ? '<img class="pimg" loading="lazy" src="/static/img/'+esc(p.image)+'" alt="'+esc(p.name)+'">'
    : '<div class="pfallback" style="--g1:'+(cat.g1||'#2a6cff')+';--g2:'+(cat.g2||'#19c6ee')+'"><span>'+esc(p.name)+'</span></div>';
  var price = p.from>0
    ? '<div class="pfoot">'+(p.plans>1?'<span class="pfrom">Starts from</span>':'')+'<span class="pprice" data-pkr="'+p.from+'"></span></div>'
    : '<div class="pfoot"><span class="pfrom">Contact for price</span></div>';
  return '<a class="pcard" href="/product/'+esc(p.slug)+'">'+img+'<div class="pbody"><div class="pname">'+esc(p.name)+'</div><div class="pdesc">'+esc(p.descr)+'</div>'+price+'</div></a>';
}
function cardsFor(slug,n){return products.filter(function(p){return p.cat===slug;}).slice(0,n||4).map(card).join('');}
var trending = products.slice(0,8);
%>

<!-- HERO -->
<section class="hero">
  <% if (heroCats.length) { %>
  <div class="hero-stage" id="heroStage">
    <% heroCats.forEach(function(c,i){ var bm=bannerMap[c.slug]||{}; %>
      <a class="hslide<%= i===0?' on':'' %>" data-i="<%= i %>" href="/category/<%= c.slug %>" aria-label="Shop <%= c.name %>">
        <picture>
          <% if (bm.mobile) { %><source media="(max-width:720px)" srcset="/static/img/<%= bm.mobile %>"><% } %>
          <img src="/static/img/<%= bm.desktop || bm.mobile %>" alt="<%= c.name %>">
        </picture>
      </a>
    <% }); %>
    <% if (heroCats.length>1) { %>
      <button class="hero-ar prev" id="heroPrev" aria-label="Previous"><svg class="ic" viewBox="0 0 24 24"><path d="m15 18-6-6 6-6"/></svg></button>
      <button class="hero-ar next" id="heroNext" aria-label="Next"><svg class="ic" viewBox="0 0 24 24"><path d="m9 6 6 6-6 6"/></svg></button>
      <div class="hero-dots" id="heroDots"></div>
    <% } %>
  </div>
  <% } else { %>
  <div class="hero-stage" style="display:grid;place-items:center;background:linear-gradient(120deg,#0b1030,#141a3a)">
    <div style="text-align:center;color:#fff;padding:40px">
      <h2 style="font-family:var(--display);font-weight:800;font-size:clamp(28px,5vw,52px);letter-spacing:-.02em;margin:0 0 12px">Premium subscriptions, delivered fast.</h2>
      <p style="color:#c7cdea;margin:0 0 22px">Upload your hero banners in Admin → Branding to feature them here.</p>
      <a class="btn btn-primary btn-lg" href="#cats">Browse the store</a>
    </div>
  </div>
  <% } %>
</section>

<!-- CREDIBILITY -->
<div class="stats reveal"><div class="wrap"><div class="stats-in">
  <div class="stat"><b><span class="star">★</span> <%= settings.rating || '4.9' %></b><span class="lbl">Average customer rating</span></div>
  <div class="stat"><b class="tnum"><%= settings.delivered || '12,000+' %></b><span class="lbl">Orders delivered</span></div>
  <div class="stat"><b>Since <%= settings.since || '2021' %></b><span class="lbl">Trusted digital store</span></div>
</div></div></div>

<!-- CATEGORY GRID -->
<section class="section reveal" id="cats">
  <div class="wrap">
    <div class="sec-head">
      <div><span class="eyebrow"><span class="dot"></span>Browse the store</span><h2>Shop by category</h2></div>
    </div>
    <div class="catgrid">
      <% cats.forEach(function(c){ %>
        <a class="cat-tile" href="/category/<%= c.slug %>" style="--g1:<%= c.g1 %>;--g2:<%= c.g2 %>">
          <span class="cg"><svg class="ic" viewBox="0 0 24 24"><%- c.icon %></svg></span>
          <span><b><%= c.name %></b><span class="n"><%= c.n %> product<%= c.n===1?'':'s' %></span></span>
        </a>
      <% }); %>
    </div>
  </div>
</section>

<!-- TRENDING -->
<% if (trending.length) { %>
<section class="section tint reveal">
  <div class="wrap">
    <div class="sec-head">
      <div><span class="eyebrow"><span class="dot"></span>Most popular right now</span><h2>Trending products</h2></div>
    </div>
    <div class="pgrid"><%- trending.map(card).join('') %></div>
  </div>
</section>
<% } %>

<!-- PER-CATEGORY SECTIONS (cards only — banners live on each category's own page) -->
<%
var tintToggle=false;
cats.forEach(function(c){
  var list=products.filter(function(p){return p.cat===c.slug;});
  if(!list.length) return;
  tintToggle=!tintToggle; %>
    <section class="section reveal<%= tintToggle?' tint':'' %>">
      <div class="wrap">
        <div class="sec-head">
          <div><span class="eyebrow"><span class="dot"></span><%= c.tag || 'Collection' %></span><h2><%= c.name %></h2></div>
          <a class="view-all" href="/category/<%= c.slug %>">View all <%= c.n %> →</a>
        </div>
        <div class="pgrid g4"><%- cardsFor(c.slug, 4) %></div>
      </div>
    </section>
<% }); %>

<!-- REVIEWS -->
<section class="section tint reveal">
  <div class="wrap">
    <div class="sec-head">
      <div><span class="eyebrow"><span class="dot"></span>What customers say</span><h2>Trusted by resellers &amp; viewers</h2></div>
    </div>
    <div class="rev-grid">
      <div class="tp-card">
        <div class="tp-score"><b><%= settings.rating || '4.9' %></b><span>/ 5</span></div>
        <div class="stars"><% for(var i=0;i<5;i++){ %><svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg><% } %></div>
        <div class="tp-sub">Based on <b class="tnum"><%= settings.reviews_count || '1,284' %></b> customer reviews</div>
        <div class="tp-logo"><svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg>Trustpilot</div>
      </div>
      <div class="rev-cards">
        <% reviews.forEach(function(r){ var initial=(r.author||'G').trim().charAt(0).toUpperCase(); %>
          <div class="rev">
            <div class="rs"><% for(var j=0;j<(r.stars||5);j++){ %><svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg><% } %></div>
            <p><%= r.body %></p>
            <div class="who"><span class="av"><%= initial %></span><div><b><%= r.author %></b><span><%= r.location || 'Verified buyer' %></span></div></div>
          </div>
        <% }); %>
      </div>
    </div>
  </div>
</section>

<%- include('partials/store_bottom') %>

GSZ_HOME_EOF

cat > "$APP/views/product.ejs" <<'GSZ_PROD_EOF'
<%- include('partials/store_top') %>
<div class="wrap pdp">
  <div class="pdp-top">
    <!-- media -->
    <div class="pdp-media" id="pdpMedia">
      <% if (p.image) { %>
        <img src="/static/img/<%= p.image %>" alt="<%= p.name %>">
      <% } else { %>
        <div class="pf" style="--g1:<%= accent.g1 %>;--g2:<%= accent.g2 %>"><%= p.name %></div>
      <% } %>
    </div>
    <!-- info -->
    <div class="pdp-info">
      <div class="crumbs"><a href="/">Home</a> &nbsp;/&nbsp; <a href="/category/<%= p.cat_slug %>"><%= p.cat_name %></a></div>
      <h1><%= p.name %></h1>
      <div class="pdp-meta">
        <span class="rt"><span class="star">★</span> <%= rating %></span>
        <span><%= Number(orders).toLocaleString('en-US') %>+ orders</span>
        <% if (p.delivery) { %><span class="chip"><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/></svg><%= p.delivery %></span><% } %>
      </div>
      <% if (p.short_desc) { %><p class="pdp-lead"><%= p.short_desc %></p><% } %>

      <% if (plans.length) { %>
      <div class="plans" id="plans">
        <% plans.forEach(function(pl,i){ %>
          <div class="plan<%= i===0?' sel':'' %>" data-label="<%= pl.label %>">
            <span class="rdo"></span>
            <span class="pl"><%= pl.label %></span>
            <span class="pp"><% if (pl.old>pl.price) { %><span class="was" data-pkr="<%= pl.old %>"></span><% } %><span data-pkr="<%= pl.price %>"></span></span>
          </div>
        <% }); %>
      </div>
      <% } %>

      <div class="buyrow">
        <a class="btn btn-primary btn-lg" id="buyBtn" href="#">Buy now</a>
        <a class="btn btn-wa btn-lg" id="waBtn" href="#" target="_blank" rel="noopener">
          <svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>Order on WhatsApp</a>
      </div>

      <div class="tchips">
        <span><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/></svg>Fast delivery</span>
        <span><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/><path d="m9 12 2 2 4-4"/></svg>Verified payments</span>
        <span><svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M4 12a8 8 0 0 1 16 0v4a3 3 0 0 1-3 3h-2v-5h5"/></svg>24/7 WhatsApp support</span>
      </div>
    </div>
  </div>

  <% if (p.long_desc && p.long_desc.trim()) { %>
  <section class="pdp-sec"><h2>About <%= p.name %></h2><div class="longdesc"><%= p.long_desc %></div></section>
  <% } %>

  <% if (faqs.length) { %>
  <section class="pdp-sec"><h2>Frequently asked questions</h2>
    <div class="faq">
      <% faqs.forEach(function(f){ %><details><summary><%= f.q %></summary><p><%= f.a %></p></details><% }); %>
    </div>
  </section>
  <% } %>

  <% if (similar.length) { %>
  <section class="pdp-sec">
    <div class="sec-head"><div><span class="eyebrow"><span class="dot"></span>You may also like</span><h2>More in <%= p.cat_name %></h2></div>
      <a class="view-all" href="/category/<%= p.cat_slug %>">View all →</a></div>
    <div class="pgrid">
      <% similar.forEach(function(s){ %>
        <a class="pcard" href="/product/<%= s.slug %>">
          <% if (s.image) { %><img class="pimg" loading="lazy" src="/static/img/<%= s.image %>" alt="<%= s.name %>">
          <% } else { %><div class="pfallback" style="--g1:<%= accent.g1 %>;--g2:<%= accent.g2 %>"><span><%= s.name %></span></div><% } %>
          <div class="pbody"><div class="pname"><%= s.name %></div><div class="pdesc"><%= s.descr %></div>
            <div class="pfoot"><% if (s.plans>1) { %><span class="pfrom">Starts from</span><% } %><span class="pprice" data-pkr="<%= s.from %>"></span></div>
          </div>
        </a>
      <% }); %>
    </div>
  </section>
  <% } %>
</div>

<script>
(function(){
  var PSLUG=<%- JSON.stringify(p.slug) %>, PNAME=<%- JSON.stringify(p.name) %>, WA=<%- JSON.stringify(waNumber) %>;
  function region(){try{return localStorage.getItem('gsz_region')||'PK';}catch(e){return 'PK';}}
  var plans=[].slice.call(document.querySelectorAll('.plan'));
  var sel=plans[0]||null;
  function update(){
    var idx=sel?plans.indexOf(sel):0;
    var buy=document.getElementById('buyBtn');
    if(buy)buy.href='/checkout?p='+encodeURIComponent(PSLUG)+'&plan='+idx+'&region='+region();
    var wa=document.getElementById('waBtn');
    if(wa){
      var label=sel?(sel.getAttribute('data-label')||''):'';
      var ppEl=sel?sel.querySelector('.pp'):null, price=ppEl?ppEl.textContent.trim():'';
      var msg='Hi! I want to order *'+PNAME+'*'+(label?(' — '+label):'')+(price?(' ('+price+')'):'')+'.';
      wa.href = WA ? ('https://wa.me/'+WA.replace(/[^0-9]/g,'')+'?text='+encodeURIComponent(msg)) : '#';
    }
  }
  plans.forEach(function(pl){pl.addEventListener('click',function(){plans.forEach(function(x){x.classList.remove('sel');});pl.classList.add('sel');sel=pl;update();});});
  // prices are painted by app.js; recompute links shortly after so WA has the figure
  update(); setTimeout(update, 300);
})();
</script>

<%- include('partials/store_bottom') %>

GSZ_PROD_EOF

cat > /tmp/gsz14_bump.js <<'GSZ_B_EOF'
const fs=require('fs');
['/opt/gsz/views/partials/store_top.ejs','/opt/gsz/views/partials/store_bottom.ejs'].forEach(function(f){
  let s=fs.readFileSync(f,'utf8');s=s.replace(/(app\.(?:css|js))\?v=\d+/g,'$1?v=14');fs.writeFileSync(f,s);
});
console.log('[ok] asset version -> v=14');
GSZ_B_EOF
node /tmp/gsz14_bump.js || { restore; exit 1; }
echo "[ok] files written"

pm2 restart gsz --update-env >/dev/null
sleep 2

SLUG=$(PSQL -tAc "SELECT slug FROM products ORDER BY sort,id LIMIT 1" | tr -d '[:space:]')
PP=$(curl -fsS "http://127.0.0.1:$PORT/product/$SLUG" || true)
HB=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
HOME=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/")
HEALTH=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health")
OKALL=1

# --- content checks via here-strings (NO curl|grep pipe under pipefail) ---
grep -q 'pdp-top'        <<< "$PP" || { echo "FAIL: product page missing pdp-top"; OKALL=0; }
if grep -q '&amp;amp;'   <<< "$PP"; then echo "FAIL: product still double-escaped"; OKALL=0; fi
grep -q 'app.css?v=14'   <<< "$HB" || { echo "FAIL: version not bumped"; OKALL=0; }
if grep -q 'iptv-band'   <<< "$HB"; then echo "FAIL: home still renders iptv-band banner"; OKALL=0; fi
if grep -q 'show-banner' <<< "$HB"; then echo "FAIL: home still renders showcase banner"; OKALL=0; fi
[ "$HOME" = "200" ]   || { echo "FAIL: home HTTP $HOME"; OKALL=0; }
[ "$HEALTH" = "200" ] || { echo "FAIL: health HTTP $HEALTH"; OKALL=0; }

if [ "$OKALL" != "1" ]; then echo "CHECK FAILED — rolling back"; restore; pm2 logs gsz --lines 20 --nostream || true; exit 1; fi
echo "============================================================"
echo "  STEP 14 OK"
echo "  - Home page: category banners removed (cards only)."
echo "  - Hero + category banners: breathing room + rounded corners."
echo "  - Product '&amp;' fix + header search fix re-applied."
echo "  - Assets now ?v=14 (hard-refresh once if cached)."
echo "============================================================"
