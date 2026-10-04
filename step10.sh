#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 10: depth, motion & hero fix
#  RUN: cd /opt/gsz-deploy && git pull && bash step10.sh
#  - Hero: stop overlaying text on banners (they have their own);
#    whole banner becomes a clean clickable slide + gentle parallax.
#  - Depth/motion: 3D cursor tilt on product & category cards,
#    in-frame image zoom, accent glow, button shine, scroll reveals.
#  - Mobile: search field now shows (wraps to its own row) instead
#    of being hidden under 760px.
#  Touches ONLY: app.css, app.js, home.ejs, category.ejs.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views" ] || { echo "ABORT: $APP/views not found."; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"; : "${DB_USER:?}"; : "${DB_NAME:?}"; : "${DB_PASS:?}"
echo "== Galaxy Subz x Zayron — Step 10 (depth & motion) · port $PORT =="
ts=$(date +%s)
PSQL(){ PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" "$@"; }

cp -a "$APP/public/css/app.css" "$APP/public/css/app.css.bak-step10.$ts"
cp -a "$APP/public/js/app.js"   "$APP/public/js/app.js.bak-step10.$ts"
cp -a "$APP/views/home.ejs"     "$APP/views/home.ejs.bak-step10.$ts"
cp -a "$APP/views/category.ejs" "$APP/views/category.ejs.bak-step10.$ts"

restore(){
  echo ">> rolling back Step 10"
  cp -a "$APP/public/css/app.css.bak-step10.$ts" "$APP/public/css/app.css"
  cp -a "$APP/public/js/app.js.bak-step10.$ts"   "$APP/public/js/app.js"
  cp -a "$APP/views/home.ejs.bak-step10.$ts"     "$APP/views/home.ejs"
  cp -a "$APP/views/category.ejs.bak-step10.$ts" "$APP/views/category.ejs"
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
.hd-search{flex:1;max-width:360px;position:relative}
.hd-search input{width:100%;height:44px;border:1px solid var(--line-2);border-radius:12px;background:var(--surface);
  padding:0 14px 0 42px;font-size:14.5px;font-family:inherit;color:var(--ink)}
.hd-search input:focus{outline:2px solid var(--b);outline-offset:1px;border-color:transparent}
.hd-search .si{position:absolute;left:13px;top:50%;transform:translateY(-50%);color:var(--muted)}
.hd-sp{flex:1}
.hd-tools{display:flex;align-items:center;gap:10px;flex:none}
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

/* ---- hero (full-bleed, no borders) ---- */
.hero{position:relative;width:100%}
.hero-stage{position:relative;width:100%;aspect-ratio:1942/809;overflow:hidden;background:var(--wash)}
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

/* ---- editorial showcase (banner-led category) ---- */
.showcase{display:grid;grid-template-columns:minmax(0,1fr);gap:22px}
.show-banner{position:relative;border-radius:var(--r-lg);overflow:hidden;aspect-ratio:1942/809;background:var(--wash)}
.show-banner img{width:100%;height:100%;object-fit:cover}
.show-banner .sb-cap{position:absolute;inset:0;display:flex;flex-direction:column;justify-content:flex-end;
  padding:clamp(18px,3vw,34px);background:linear-gradient(0deg,rgba(6,10,28,.78),transparent 70%);color:#fff}
.show-banner .sb-cap h3{font-family:var(--display);font-weight:800;font-size:clamp(20px,2.6vw,30px);letter-spacing:-.02em;margin:0 0 6px}
.show-banner .sb-cap p{margin:0;color:#dfe4f6;font-size:14.5px;max-width:48ch}

/* ---- IPTV immersive band ---- */
.iptv-band{position:relative;overflow:hidden;background:#070b1d;color:#fff}
.iptv-band>img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;opacity:.26}
.iptv-band .ib-in{position:relative;padding:clamp(44px,6vw,76px) 0}
.iptv-band .ib-head{max-width:620px;margin-bottom:28px}
.iptv-band .ib-head .eyebrow{color:var(--c)}
.iptv-band .ib-head h2{font-family:var(--display);font-weight:800;font-size:clamp(26px,3.4vw,40px);letter-spacing:-.025em;margin:8px 0 12px;line-height:1.03}
.iptv-band .ib-head p{color:#c7cdea;font-size:16px;max-width:52ch;margin:0}
.iptv-band .pcard{background:rgba(255,255,255,.05);border-color:rgba(255,255,255,.1)}
.iptv-band .pcard .pname{color:#fff}
.iptv-band .pcard .pdesc{color:#aab2d6}
.iptv-band .pcard .pprice{color:#fff}
.iptv-band .view-all{color:var(--c)}

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
.reveal{opacity:0;transform:translateY(26px);transition:opacity .7s ease,transform .7s cubic-bezier(.2,.7,.3,1)}
.reveal.in{opacity:1;transform:none}
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
GSZ_CSS_EOF

cat > "$APP/public/js/app.js" <<'GSZ_JS_EOF'
/* ===== Galaxy Subz × Zayron — storefront (v2) =====
   Server renders the markup; this handles interaction only:
   region prices, live search, hero carousel, drawer, marquee, toss. */
(function(){
'use strict';
var D = (window.__DATA)||{cats:[],products:[],settings:{},wa:''};
var CATS = D.cats||[], PRODUCTS = D.products||[];
var reduce = matchMedia('(prefers-reduced-motion:reduce)').matches;
var $ = function(s,r){return (r||document).querySelector(s);};
var $$ = function(s,r){return Array.prototype.slice.call((r||document).querySelectorAll(s));};

/* ---------- region + prices ---------- */
var REGIONS=[
  {code:'PK',cur:'Rs',rate:1,label:'PK · Rs',cc:'pk'},
  {code:'US',cur:'$',rate:0.0036,label:'US · $',cc:'us'},
  {code:'GB',cur:'£',rate:0.0028,label:'UK · £',cc:'gb'},
  {code:'AE',cur:'AED',rate:0.013,label:'AE · AED',cc:'ae'}
];
var REGION=REGIONS[0];
try{var sv=localStorage.getItem('gsz_region');if(sv){var f=REGIONS.filter(function(r){return r.code===sv;})[0];if(f)REGION=f;}}catch(e){}
function flag(cc){return 'https://flagcdn.com/24x18/'+cc+'.png';}
function money(pkr){pkr=Number(pkr)||0;var v=pkr*REGION.rate;
  if(REGION.cur==='Rs')return 'Rs '+Math.round(pkr).toLocaleString('en-US');
  return REGION.cur+' '+(v<10?v.toFixed(2):Math.round(v).toLocaleString('en-US'));}
function paintPrices(root){$$('[data-pkr]',root).forEach(function(el){el.textContent=money(el.dataset.pkr);});}
function setRegion(code){
  var f=REGIONS.filter(function(r){return r.code===code;})[0]; if(!f)return;
  REGION=f;
  var lab=$('#regionLabel'); if(lab)lab.textContent=f.label;
  var fl=$('#regionFlag'); if(fl)fl.src=flag(f.cc);
  paintPrices();
  $$('#regionMenu button').forEach(function(b){b.classList.toggle('on',b.dataset.region===code);});
  $$('#drawerRegion button').forEach(function(b){b.classList.toggle('on',b.dataset.region===code);});
  try{localStorage.setItem('gsz_region',code);}catch(e){}
}
function buildRegionMenu(){
  var m=$('#regionMenu'); if(m)m.innerHTML=REGIONS.map(function(r){
    return '<button data-region="'+r.code+'" class="'+(r.code===REGION.code?'on':'')+'"><img class="flag" src="'+flag(r.cc)+'" alt="">'+r.label+'</button>';}).join('');
  var dr=$('#drawerRegion'); if(dr)dr.innerHTML=REGIONS.map(function(r){
    return '<button data-region="'+r.code+'" class="'+(r.code===REGION.code?'on':'')+'">'+r.cur+'</button>';}).join('');
}

/* ---------- marquee ---------- */
function buildMarquee(){
  var el=$('#marqueeList'); if(!el)return;
  var items=['Instant automated delivery','Pay in PKR, USD or crypto','Verified before we deliver','Real WhatsApp support','Free IPTV trial available'];
  var shield='<svg class="ic ic-sm" viewBox="0 0 24 24"><path d="M12 3 4 6v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V6l-8-3Z"/></svg>';
  var row=items.map(function(t){return '<li>'+shield+t+'</li>';}).join('');
  el.innerHTML=row+row;
}

/* ---------- drawer ---------- */
function buildDrawerCats(){
  var el=$('#drawerCats'); if(!el)return;
  el.innerHTML=CATS.map(function(c){
    return '<a class="dcat" href="/category/'+c.slug+'" style="--g1:'+(c.g1||'#2a6cff')+';--g2:'+(c.g2||'#19c6ee')+'">'+
      '<span class="cg"><svg class="ic" viewBox="0 0 24 24">'+(c.icon||'')+'</svg></span>'+
      '<span><b>'+c.name+'</b><span class="n">'+c.n+' product'+(c.n===1?'':'s')+'</span></span></a>';}).join('');
}
function openDrawer(){$('#drawer').classList.add('on');$('#scrim').classList.add('on');}
function closeDrawer(){$('#drawer').classList.remove('on');$('#scrim').classList.remove('on');}

/* ---------- live search (inline, no popup) ---------- */
function searchThumb(p){
  if(p.image)return '<img class="th" src="/static/img/'+p.image+'" alt="">';
  return '<span class="th" style="display:grid;place-items:center;color:#fff;font-weight:700;background:linear-gradient(135deg,#2a6cff,#19c6ee)">'+(p.name||'?').charAt(0).toUpperCase()+'</span>';
}
function runSearch(q){
  var box=$('#searchRes'); if(!box)return;
  q=(q||'').trim().toLowerCase();
  if(!q){box.classList.remove('on');box.innerHTML='';return;}
  var hits=PRODUCTS.filter(function(p){return (p.name||'').toLowerCase().indexOf(q)>-1 || (p.cat||'').toLowerCase().indexOf(q)>-1;}).slice(0,8);
  if(!hits.length){box.innerHTML='<div class="sempty">No products match “'+q.replace(/</g,'')+'”.</div>';box.classList.add('on');return;}
  box.innerHTML=hits.map(function(p){
    return '<a class="sresult" href="/product/'+p.slug+'">'+searchThumb(p)+
      '<span><span class="nm">'+p.name+'</span><span class="mt">'+(p.catName||p.cat||'')+'</span></span>'+
      (p.from>0?'<span class="pr">'+money(p.from)+'</span>':'')+'</a>';}).join('');
  box.classList.add('on');
}

/* ---------- hero carousel (opacity only, no zoom) ---------- */
function initHero(){
  var stage=$('#heroStage'); if(!stage)return;
  var slides=$$('.hslide',stage); if(slides.length<2){return;}
  var dots=$('#heroDots'), cur=0, timer;
  if(dots)dots.innerHTML=slides.map(function(_,i){return '<button data-i="'+i+'" class="'+(i===0?'on':'')+'" aria-label="Slide '+(i+1)+'"></button>';}).join('');
  function go(i){cur=(i+slides.length)%slides.length;
    slides.forEach(function(s,k){s.classList.toggle('on',k===cur);});
    if(dots)$$('button',dots).forEach(function(b,k){b.classList.toggle('on',k===cur);});}
  function start(){if(reduce)return;clearInterval(timer);timer=setInterval(function(){go(cur+1);},6500);}
  var pv=$('#heroPrev'),nx=$('#heroNext');
  if(pv)pv.onclick=function(){go(cur-1);start();};
  if(nx)nx.onclick=function(){go(cur+1);start();};
  if(dots)dots.addEventListener('click',function(e){var b=e.target.closest('button');if(b){go(+b.dataset.i);start();}});
  stage.addEventListener('mouseenter',function(){clearInterval(timer);});
  stage.addEventListener('mouseleave',start);
  start();
}

/* ---------- toss (social proof) — slow, minutes apart ---------- */
var tossT;
function showToss(){
  var el=$('#toss'); if(!el||!PRODUCTS.length)return;
  var cities=['Karachi','Lahore','Islamabad','Dubai','London','Rawalpindi','Faisalabad','Manchester','Toronto','Riyadh'];
  var p=PRODUCTS[Math.floor(Math.random()*PRODUCTS.length)];
  var city=cities[Math.floor(Math.random()*cities.length)];
  var mins=2+Math.floor(Math.random()*28);
  el.innerHTML='<span class="tt"><svg class="ic ic-sm" viewBox="0 0 24 24" style="stroke:#fff"><path d="M20 6 9 17l-5-5"/></svg></span>'+
    '<span class="tb"><b>'+p.name+'</b><span>Someone in '+city+' ordered · '+mins+' min ago</span></span>'+
    '<button class="tx" aria-label="Dismiss">✕</button>';
  el.href='/product/'+p.slug; el.style.display='flex';
  requestAnimationFrame(function(){el.classList.add('on');});
  clearTimeout(tossT); tossT=setTimeout(function(){el.classList.remove('on');},6500);
}
function startToss(){
  if(reduce)return;
  setTimeout(function loop(){showToss();setTimeout(loop,180000+Math.random()*180000);},45000);
}

/* ---------- toast ---------- */
var toastT;
function toast(m){var t=$('#toast');if(!t)return;t.textContent=m;t.classList.add('on');clearTimeout(toastT);toastT=setTimeout(function(){t.classList.remove('on');},2600);}

/* ---------- motion & depth ---------- */
function initTilt(){
  if(matchMedia('(pointer:coarse)').matches || reduce)return;
  $$('.pcard, .cat-tile').forEach(function(el){
    el.addEventListener('pointermove',function(e){
      var r=el.getBoundingClientRect();
      var px=(e.clientX-r.left)/r.width-0.5, py=(e.clientY-r.top)/r.height-0.5;
      el.style.transform='perspective(820px) rotateX('+(-py*6).toFixed(2)+'deg) rotateY('+(px*7).toFixed(2)+'deg) translateY(-4px)';
    });
    el.addEventListener('pointerleave',function(){el.style.transform='';});
  });
}
function initReveal(){
  var els=$$('.reveal');
  if(reduce || !('IntersectionObserver' in window)){els.forEach(function(e){e.classList.add('in');});return;}
  var io=new IntersectionObserver(function(ents){ents.forEach(function(en){if(en.isIntersecting){en.target.classList.add('in');io.unobserve(en.target);}});},{threshold:0.12,rootMargin:'0px 0px -8% 0px'});
  els.forEach(function(e){io.observe(e);});
}
function initParallax(){
  if(reduce)return;
  var imgs=$$('#heroStage .hslide img'); if(!imgs.length)return;
  imgs.forEach(function(im){im.style.transform='scale(1.08)';});
  var tick=false;
  addEventListener('scroll',function(){
    if(tick)return; tick=true;
    requestAnimationFrame(function(){
      var y=scrollY;
      if(y<720)imgs.forEach(function(im){im.style.transform='translateY('+(y*0.12).toFixed(1)+'px) scale(1.08)';});
      tick=false;
    });
  },{passive:true});
}

/* ---------- wire ---------- */
function wire(){
  buildRegionMenu(); buildMarquee(); buildDrawerCats();
  setRegion(REGION.code); paintPrices();
  initHero(); startToss();
  initReveal(); initTilt(); initParallax();

  var rb=$('#regionBtn'); if(rb)rb.onclick=function(e){e.stopPropagation();$('#regionMenu').classList.toggle('on');};
  document.addEventListener('click',function(e){
    if(!e.target.closest('.pos-rel')){var m=$('#regionMenu');if(m)m.classList.remove('on');}
    var rbtn=e.target.closest('[data-region]'); if(rbtn){setRegion(rbtn.dataset.region);var m2=$('#regionMenu');if(m2)m2.classList.remove('on');}
    var sc=e.target.closest('[data-scroll]'); if(sc){e.preventDefault();var t=document.getElementById(sc.dataset.scroll);if(t)window.scrollTo({top:t.getBoundingClientRect().top+scrollY-90,behavior:'smooth'});}
    var tt=e.target.closest('[data-toast]'); if(tt){e.preventDefault();toast(tt.dataset.toast);}
    if(!e.target.closest('.hd-search')){var sr=$('#searchRes');if(sr)sr.classList.remove('on');}
  });

  var si=$('#searchInput');
  if(si){si.addEventListener('input',function(){runSearch(si.value);});
    si.addEventListener('focus',function(){if(si.value)runSearch(si.value);});}

  var bg=$('#burger'); if(bg)bg.onclick=openDrawer;
  var dx=$('#drawerX'); if(dx)dx.onclick=closeDrawer;
  var sc=$('#scrim'); if(sc)sc.onclick=closeDrawer;

  var cc=$('#codeChip'); if(cc)cc.onclick=function(){try{navigator.clipboard.writeText('GALAXY10');toast('Code GALAXY10 copied');}catch(e){toast('Code: GALAXY10');}};

  var toss=$('#toss'); if(toss)toss.addEventListener('click',function(e){if(e.target.closest('.tx')){e.preventDefault();toss.classList.remove('on');}});

  var hd=$('#hd'); addEventListener('scroll',function(){hd.classList.toggle('scrolled',scrollY>8);},{passive:true});
  addEventListener('keydown',function(e){if(e.key==='Escape'){closeDrawer();var sr=$('#searchRes');if(sr)sr.classList.remove('on');var rm=$('#regionMenu');if(rm)rm.classList.remove('on');}});
}
if(document.readyState!=='loading')wire(); else document.addEventListener('DOMContentLoaded',wire);
})();
GSZ_JS_EOF

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

<!-- PER-CATEGORY SECTIONS (varied rhythm) -->
<%
var usedShowcase=false; var tintToggle=false;
cats.forEach(function(c){
  var list=products.filter(function(p){return p.cat===c.slug;});
  if(!list.length) return;
  var bm=bannerMap[c.slug]||{};
  if(c.slug==='iptv'){ %>
    <section class="iptv-band reveal">
      <% if (bm.desktop || bm.mobile) { %><img src="/static/img/<%= bm.desktop||bm.mobile %>" alt=""><% } %>
      <div class="wrap ib-in">
        <div class="ib-head">
          <span class="eyebrow"><span class="dot" style="background:var(--c)"></span>Live TV &amp; sports</span>
          <h2><%= c.name %></h2>
          <p>Thousands of channels and VOD in crisp quality — free trial, instant activation and renewals, on every device.</p>
        </div>
        <div class="pgrid g4"><%- cardsFor(c.slug,4) %></div>
        <div style="margin-top:22px"><a class="view-all" href="/category/<%= c.slug %>">View all <%= c.name %> →</a></div>
      </div>
    </section>
<%} else if(!usedShowcase && (bm.desktop||bm.mobile)){ usedShowcase=true; %>
    <section class="section reveal">
      <div class="wrap">
        <div class="showcase">
          <a class="show-banner" href="/category/<%= c.slug %>">
            <img src="/static/img/<%= bm.desktop||bm.mobile %>" alt="<%= c.name %>">
            <div class="sb-cap"><h3><%= c.name %></h3><p><%= c.tag || 'Hand-picked premium picks.' %></p></div>
          </a>
          <div>
            <div class="sec-head"><div><span class="eyebrow"><span class="dot"></span>Featured</span><h2><%= c.name %></h2></div>
              <a class="view-all" href="/category/<%= c.slug %>">View all →</a></div>
            <div class="pgrid g4"><%- cardsFor(c.slug,4) %></div>
          </div>
        </div>
      </div>
    </section>
<%} else { tintToggle=!tintToggle; %>
    <section class="section reveal<%= tintToggle?' tint':'' %>">
      <div class="wrap">
        <div class="sec-head">
          <div><span class="eyebrow"><span class="dot"></span><%= c.tag || 'Collection' %></span><h2><%= c.name %></h2></div>
          <a class="view-all" href="/category/<%= c.slug %>">View all <%= c.n %> →</a>
        </div>
        <div class="pgrid g4"><%- cardsFor(c.slug,4) %></div>
      </div>
    </section>
<% }
}); %>

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

cat > "$APP/views/category.ejs" <<'GSZ_CATV_EOF'
<%- include('partials/store_top') %>
<%
function esc(s){return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
function card(p){
  var img=p.image
    ? '<img class="pimg" loading="lazy" src="/static/img/'+esc(p.image)+'" alt="'+esc(p.name)+'">'
    : '<div class="pfallback" style="--g1:'+(cat.g1||'#2a6cff')+';--g2:'+(cat.g2||'#19c6ee')+'"><span>'+esc(p.name)+'</span></div>';
  var price = p.from>0
    ? '<div class="pfoot">'+(p.plans>1?'<span class="pfrom">Starts from</span>':'')+'<span class="pprice" data-pkr="'+p.from+'"></span></div>'
    : '<div class="pfoot"><span class="pfrom">Contact for price</span></div>';
  return '<a class="pcard" href="/product/'+esc(p.slug)+'">'+img+'<div class="pbody"><div class="pname">'+esc(p.name)+'</div><div class="pdesc">'+esc(p.descr)+'</div>'+price+'</div></a>';
}
var bm = bannerMap[cat.slug] || {};
%>

<!-- CATEGORY HERO -->
<section class="hero">
  <% if (bm.desktop || bm.mobile) { %>
  <div class="hero-stage">
    <div class="hslide on">
      <picture>
        <% if (bm.mobile) { %><source media="(max-width:720px)" srcset="/static/img/<%= bm.mobile %>"><% } %>
        <img src="/static/img/<%= bm.desktop || bm.mobile %>" alt="<%= cat.name %>">
      </picture>
    </div>
  </div>
  <% } else { %>
  <div class="hero-stage" style="display:grid;place-items:center;background:linear-gradient(135deg,<%= cat.g1 %>,<%= cat.g2 %>)">
    <div style="text-align:center;color:#fff;padding:36px">
      <h2 style="font-family:var(--display);font-weight:800;font-size:clamp(28px,5vw,48px);letter-spacing:-.02em;margin:0"><%= cat.name %></h2>
      <p style="color:rgba(255,255,255,.85);margin:10px 0 0"><%= cat.tag || 'Premium subscriptions, delivered fast.' %></p>
    </div>
  </div>
  <% } %>
</section>

<!-- PRODUCTS -->
<section class="section reveal">
  <div class="wrap">
    <div class="sec-head">
      <div>
        <span class="eyebrow"><a href="/" style="color:inherit">Home</a> &nbsp;/&nbsp; <%= cat.name %></span>
        <h2><%= cat.name %> <span style="color:var(--muted);font-weight:600;font-size:.6em">(<%= products.length %>)</span></h2>
      </div>
    </div>
    <% if (products.length) { %>
      <div class="pgrid"><%- products.map(card).join('') %></div>
    <% } else { %>
      <p style="color:var(--muted)">No products in this category yet. Please check back soon.</p>
    <% } %>
  </div>
</section>

<%- include('partials/store_bottom') %>
GSZ_CATV_EOF

echo "[ok] files written"
node --check "$APP/public/js/app.js" || { restore; exit 1; }
echo "[ok] app.js parses"

pm2 restart gsz --update-env >/dev/null
sleep 2
CSLUG=$(PSQL -tAc "SELECT slug FROM categories WHERE active ORDER BY sort,id LIMIT 1" | tr -d '[:space:]')
HOME=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
CAT=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/category/$CSLUG")
HEALTH=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health")

OKALL=1
echo "$HOME" | grep -q 'hero-stage'        || { echo "FAIL: hero missing"; OKALL=0; }
if echo "$HOME" | grep -q 'class="cap"'; then echo "FAIL: hero text overlay still present"; OKALL=0; fi
echo "$HOME" | grep -q "reveal"            || { echo "FAIL: reveal hooks missing"; OKALL=0; }
echo "$HOME" | grep -q "Shop by category"  || { echo "FAIL: homepage broke"; OKALL=0; }
[ "$CAT" = "200" ]                         || { echo "FAIL: category page (HTTP $CAT)"; OKALL=0; }
[ "$HEALTH" = "200" ]                      || { echo "FAIL: health (HTTP $HEALTH)"; OKALL=0; }

if [ "$OKALL" != "1" ]; then echo "CHECK FAILED — rolling back"; restore; pm2 logs gsz --lines 25 --nostream || true; exit 1; fi

echo "============================================================"
echo " STEP 10 COMPLETE — depth, motion & hero fix live"
echo "   home: http://143.198.209.68:$PORT/"
echo "   Hero banners are clean + clickable (no text collision),"
echo "   cards tilt in 3D with glow + image zoom, sections reveal on"
echo "   scroll, and search now shows on mobile."
echo "   NEXT: Step 11 — full product-page redesign on this system."
echo "============================================================"
