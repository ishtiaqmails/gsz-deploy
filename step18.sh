#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 18: premium DARK theme
#  RUN: cd /opt/gsz-deploy && git pull && bash step18.sh
#   - Full dark, high-end design system (deep backgrounds, brand glow,
#     glass header, dark cards with depth, premium shadows).
#   - Removes any horizontal scrollbar site-wide (overflow-x:clip guard
#     + reviews-row min-width:0 fix).
#   - Pure re-skin: only public/css/app.css changes; all markup stays.
#  Asset version -> v=18. Auto-rollback on health-check failure.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views" ] || { echo "ABORT: $APP/views not found"; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"
echo "== Galaxy Subz x Zayron — Step 18 (premium dark theme) · port $PORT =="
ts=$(date +%s)
cp -a "$APP/public/css/app.css"              "$APP/public/css/app.css.bak-step18.$ts"
cp -a "$APP/views/partials/store_top.ejs"    "$APP/views/partials/store_top.ejs.bak-step18.$ts"
cp -a "$APP/views/partials/store_bottom.ejs" "$APP/views/partials/store_bottom.ejs.bak-step18.$ts"
restore(){
  echo ">> rolling back Step 18"
  cp -a "$APP/public/css/app.css.bak-step18.$ts"              "$APP/public/css/app.css"
  cp -a "$APP/views/partials/store_top.ejs.bak-step18.$ts"    "$APP/views/partials/store_top.ejs"
  cp -a "$APP/views/partials/store_bottom.ejs.bak-step18.$ts" "$APP/views/partials/store_bottom.ejs"
  pm2 restart gsz >/dev/null 2>&1 || true
}
cat > "$APP/public/css/app.css" <<'GSZ_CSS18'
/* ============================================================
   GALAXY SUBZ × ZAYRON — storefront design system (dark v3)
   Dark, high-end. One system driven by CSS tokens.
   ============================================================ */
:root{
  color-scheme:dark;
  /* dark premium palette */
  --bg0:#05060d;              /* deepest */
  --paper:#080a14;           /* page background */
  --surface:#111322;         /* elevated card */
  --surface-2:#161a2c;       /* hover / raised */
  --ink:#eef1ff; --ink-soft:#c4cae8; --muted:#8b93bb;
  --line:rgba(255,255,255,.08); --line-2:rgba(255,255,255,.16);
  --v:#8b45ff; --b:#3b82ff; --c:#28d6ff;
  --brand:linear-gradient(100deg,#8b45ff,#3b82ff 55%,#28d6ff);
  --wash:#0e1120;            /* subtle elevated tint band */
  --ok:#2ad17f; --warn:#f2b24a;
  --display:'Bricolage Grotesque',system-ui,sans-serif;
  --body:'Hanken Grotesk',system-ui,'Segoe UI',sans-serif;
  --wrap:1480px; --gut:clamp(16px,3vw,44px);
  --r:16px; --r-sm:11px; --r-lg:22px;
  --shadow:0 2px 10px rgba(0,0,0,.4),0 18px 40px -24px rgba(0,0,0,.7);
  --shadow-lg:0 10px 30px rgba(0,0,0,.45),0 40px 80px -30px rgba(0,0,0,.8);
  --glow:0 0 0 1px rgba(255,255,255,.04),0 20px 60px -24px rgba(59,130,255,.55);
}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%;overflow-x:clip}
body{overflow-x:clip;max-width:100%}
body{margin:0;color:var(--ink);font-family:var(--body);
  font-size:16px;line-height:1.5;-webkit-font-smoothing:antialiased;
  background:
    radial-gradient(900px 600px at 12% -5%,rgba(139,69,255,.16),transparent 60%),
    radial-gradient(1000px 650px at 100% 0%,rgba(40,214,255,.12),transparent 55%),
    var(--paper);
  background-attachment:fixed}
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
.btn-dark{background:var(--surface-2);color:var(--ink);box-shadow:inset 0 0 0 1px var(--line-2)}
.btn-dark:hover{transform:translateY(-1px)}
.btn-ghost{background:var(--surface);color:var(--ink);box-shadow:inset 0 0 0 1px var(--line-2)}
.btn-ghost:hover{box-shadow:inset 0 0 0 1.5px var(--b);color:var(--b)}
.btn-wa{background:#1fb457;color:#fff}
.btn-wa:hover{background:#19a04d;transform:translateY(-1px)}
.btn-lg{padding:15px 26px;font-size:16px;border-radius:14px}

/* ---- offer bar (no close button) ---- */
.offer{background:linear-gradient(90deg,#0a0c18,#120a24 50%,#0a0c18);border-bottom:1px solid var(--line);color:#fff;font-size:13.5px;overflow:hidden}
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
.hd{position:sticky;top:0;z-index:50;background:rgba(8,10,20,.72);backdrop-filter:blur(16px) saturate(1.2);
  border-bottom:1px solid var(--line);transition:border-color .2s,box-shadow .2s}
.hd.scrolled{border-color:var(--line-2);box-shadow:0 10px 30px -18px rgba(0,0,0,.8)}
.hd-in{display:flex;align-items:center;gap:20px;height:76px}
.brand{display:flex;align-items:center;gap:9px;flex:none}
.brand img{height:40px;width:auto}
.wordmark{font-family:var(--display);font-weight:800;font-size:21px;letter-spacing:-.02em}
.nav{display:flex;align-items:center;gap:4px}
.nav a{padding:9px 13px;border-radius:9px;font-weight:600;font-size:15px;color:var(--ink-soft);transition:.15s}
.nav a:hover{background:var(--wash);color:var(--ink)}
.hd-search{flex:1;max-width:640px;min-width:240px;position:relative}
.hd-search input{width:100%;height:48px;border:1px solid var(--line-2);border-radius:13px;background:var(--surface);
  padding:0 16px 0 46px;font-size:15px;font-family:inherit;color:var(--ink)}
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
.sresults{position:absolute;left:0;right:0;top:calc(100% + 8px);min-width:360px;background:var(--surface);border:1px solid var(--line);
  border-radius:14px;box-shadow:var(--shadow-lg);padding:6px;max-height:min(72vh,520px);overflow-y:auto;overflow-x:hidden;display:none;z-index:70}
.sresult .nm{white-space:normal;line-height:1.25}
.sresults.on{display:block}
.sresult{display:flex;align-items:center;gap:12px;padding:9px 11px;border-radius:10px}
.sresult:hover{background:var(--wash)}
.sresult .th{width:40px;height:40px;border-radius:9px;object-fit:cover;flex:none;background:var(--wash)}
.sresult .nm{font-weight:600;font-size:14px}
.sresult .mt{font-size:12.5px;color:var(--muted)}
.sresult .pr{margin-left:auto;font-weight:700;font-size:13.5px}
.sempty{padding:18px 12px;color:var(--muted);font-size:14px;text-align:center}

/* ---- hero (inset, rounded, shows the WHOLE banner — never cropped) ---- */
.hero{position:relative;width:100%;padding:clamp(12px,1.8vw,22px) var(--gut) 0}
.hero-stage{position:relative;width:100%;max-width:1760px;margin-inline:auto;overflow:hidden;border-radius:var(--r-lg);background:var(--wash);border:1px solid var(--line);box-shadow:0 40px 90px -40px rgba(59,130,255,.5),0 0 0 1px rgba(255,255,255,.04)}
.hslide{position:absolute;inset:0;opacity:0;transition:opacity .7s ease;pointer-events:none}
.hslide.on{position:relative;opacity:1;pointer-events:auto}
.hslide{display:block}
.hslide img,.hslide picture{width:100%;height:auto;display:block}
.hero-dots{position:absolute;right:var(--gut);bottom:18px;display:flex;gap:7px;z-index:3}
.hero-dots button{width:9px;height:9px;border-radius:999px;border:0;background:rgba(255,255,255,.45);cursor:pointer;padding:0}
.hero-dots button.on{background:#fff;width:24px}
.hero-ar{position:absolute;top:50%;transform:translateY(-50%);width:44px;height:44px;border-radius:999px;
  border:0;background:rgba(10,14,34,.42);color:#fff;display:grid;place-items:center;cursor:pointer;z-index:3}
.hero-ar:hover{background:rgba(10,14,34,.7)}
.hero-ar.prev{left:14px}.hero-ar.next{right:14px}
@media(max-width:720px){.hero{padding-top:10px}.hero-ar{display:none}}

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
.section{padding:clamp(26px,3.4vw,46px) 0}
.section.tint{background:var(--wash)}
/* immersive dark band — adds variety between categories */
.section.dark{background:radial-gradient(1200px 500px at 15% -10%,rgba(122,43,255,.5),transparent 60%),radial-gradient(1000px 500px at 110% 20%,rgba(25,198,238,.4),transparent 55%),#0b1030;color:#fff}
.section.dark .sec-head h2{color:#fff}
.section.dark .eyebrow{color:#c7cdea}
.section.dark .pcard{background:rgba(255,255,255,.06);border-color:rgba(255,255,255,.12);backdrop-filter:blur(6px)}
.section.dark .pcard .pname{color:#fff}
.section.dark .pcard .pdesc{color:#aab2d6}
.section.dark .pcard .pprice{color:#fff}
.section.dark .pcard .pfrom{color:#9aa3cc}
.section.dark .view-all{color:var(--c)}
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
.pgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(212px,1fr));gap:18px}
.pgrid.g4{grid-template-columns:repeat(auto-fill,minmax(212px,1fr))}
@media(max-width:620px){.pgrid,.pgrid.g4{grid-template-columns:repeat(2,1fr);gap:12px}}
.pcard{position:relative;display:flex;flex-direction:column;background:linear-gradient(180deg,rgba(255,255,255,.035),rgba(255,255,255,0) 40%),var(--surface);border:1px solid var(--line);
  border-radius:var(--r);overflow:hidden;transform-style:preserve-3d;will-change:transform;
  transition:transform .2s cubic-bezier(.2,.7,.3,1),box-shadow .25s ease,border-color .2s}
.pcard:hover{box-shadow:0 30px 70px -26px rgba(59,130,255,.6),0 0 0 1px rgba(59,130,255,.25);border-color:transparent}
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

/* ---- reviews (single scrolling row) ---- */
.rev-grid{display:grid;grid-template-columns:300px 1fr;gap:24px;align-items:start}
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
.rev-cards{display:flex;gap:16px;overflow-x:auto;min-width:0;padding:6px 2px 14px;scroll-snap-type:x mandatory;scrollbar-width:thin}
.rev-cards::-webkit-scrollbar{height:7px}
.rev-cards::-webkit-scrollbar-thumb{background:var(--line-2);border-radius:999px}
.rev{flex:0 0 300px;scroll-snap-align:start;background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:18px;
  transform-style:preserve-3d;will-change:transform;transition:transform .2s cubic-bezier(.2,.7,.3,1),box-shadow .25s}
.rev:hover{box-shadow:0 26px 56px -28px rgba(42,108,255,.5);border-color:transparent}
@media(max-width:520px){.rev{flex-basis:84vw}}
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
.ft{background:linear-gradient(180deg,var(--bg0),#070812);border-top:1px solid var(--line);color:#aab2d6;padding:56px 0 30px}
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
.toss .tt{width:44px;height:44px;border-radius:11px;display:grid;place-items:center;color:#fff;font-weight:800;flex:none;background:var(--brand);overflow:hidden}
.toss .tt-img{padding:0}
.toss .tt img{width:100%;height:100%;object-fit:cover;border-radius:11px}
.toss .tb b{font-size:13.5px;display:block}
.toss .tb span{font-size:12px;color:var(--muted)}
.toss .tx{position:absolute;top:-8px;right:-8px;width:22px;height:22px;border-radius:999px;background:var(--surface-2);
  color:#fff;border:1px solid var(--line-2);display:grid;place-items:center;cursor:pointer;font-size:12px}

/* ---- toast ---- */
.toast{position:fixed;left:50%;bottom:26px;transform:translateX(-50%) translateY(140%);z-index:95;
  background:var(--surface-2);color:#fff;border:1px solid var(--line-2);border-radius:12px;padding:12px 18px;font-size:14px;font-weight:500;
  box-shadow:var(--shadow-lg);transition:transform .3s;max-width:90vw}
.toast.on{transform:translateX(-50%)}

/* ---- currency modal (world currencies) ---- */
.cur-modal{position:fixed;inset:0;z-index:120;display:none}
.cur-modal.on{display:block}
.cur-backdrop{position:absolute;inset:0;background:rgba(5,6,13,.7);backdrop-filter:blur(4px);animation:fade .2s ease}
@keyframes fade{from{opacity:0}to{opacity:1}}
.cur-sheet{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);width:min(560px,92vw);max-height:84vh;
  background:var(--surface);border:1px solid var(--line-2);border-radius:18px;box-shadow:var(--shadow-lg);
  display:flex;flex-direction:column;overflow:hidden;animation:pop .22s cubic-bezier(.2,.7,.3,1)}
@keyframes pop{from{opacity:0;transform:translate(-50%,-46%) scale(.97)}to{opacity:1;transform:translate(-50%,-50%) scale(1)}}
.cur-head{display:flex;align-items:flex-start;justify-content:space-between;gap:14px;padding:20px 20px 14px}
.cur-head h3{font-family:var(--display);font-weight:800;font-size:19px;letter-spacing:-.01em;margin:0}
.cur-head p{margin:4px 0 0;color:var(--muted);font-size:13px}
.cur-x{flex:none;width:36px;height:36px;border-radius:10px;border:1px solid var(--line-2);background:var(--surface);color:var(--ink);cursor:pointer;display:grid;place-items:center}
.cur-x:hover{border-color:var(--b);color:var(--b)}
.cur-search{position:relative;margin:0 20px 12px}
.cur-search svg{position:absolute;left:13px;top:50%;transform:translateY(-50%);color:var(--muted)}
.cur-search input{width:100%;height:46px;border:1px solid var(--line-2);border-radius:12px;background:var(--wash);
  padding:0 14px 0 42px;font-size:15px;font-family:inherit;color:var(--ink)}
.cur-search input:focus{outline:2px solid var(--b);outline-offset:1px;border-color:transparent;background:var(--surface)}
.cur-list{overflow-y:auto;padding:0 12px 14px;display:grid;grid-template-columns:1fr 1fr;gap:6px}
@media(max-width:520px){.cur-list{grid-template-columns:1fr}}
.cur-item{display:flex;align-items:center;gap:10px;width:100%;border:1px solid transparent;background:none;
  padding:10px 11px;border-radius:11px;cursor:pointer;text-align:left;color:var(--ink);transition:.12s}
.cur-item:hover{background:var(--wash)}
.cur-item.on{border-color:var(--b);background:color-mix(in srgb,var(--b) 22%,transparent)}
.cur-item .flag{width:22px;height:16px;border-radius:3px;object-fit:cover;flex:none}
.cur-item .cc{font-weight:800;font-size:13.5px;font-family:var(--display);width:40px;flex:none}
.cur-item .cn{font-size:13px;color:var(--ink-soft);flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.cur-item .cs{font-size:12.5px;color:var(--muted);font-weight:600;flex:none}

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

/* animated gradient numbers (count-up) */
.gradnum{background:var(--brand);-webkit-background-clip:text;background-clip:text;color:transparent;background-size:200% 100%;animation:hue 6s linear infinite;font-variant-numeric:tabular-nums}
.stat .star{color:#f5b301}
@keyframes hue{to{background-position:200% 0}}
/* gradient ring on category tiles for depth */
.cat-tile{position:relative;isolation:isolate}
.cat-tile::before{content:"";position:absolute;inset:-1px;border-radius:inherit;padding:1px;background:linear-gradient(135deg,var(--g1,#2a6cff),var(--g2,#19c6ee));-webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);-webkit-mask-composite:xor;mask-composite:exclude;opacity:0;transition:opacity .2s;z-index:-1}
.cat-tile:hover::before{opacity:1}
/* eyebrow dot pulse */
.sec-head .eyebrow .dot{box-shadow:0 0 0 0 rgba(42,108,255,.5);animation:pulse 2.6s ease-out infinite}
@keyframes pulse{0%{box-shadow:0 0 0 0 rgba(42,108,255,.45)}70%{box-shadow:0 0 0 7px rgba(42,108,255,0)}100%{box-shadow:0 0 0 0 rgba(42,108,255,0)}}

@media(prefers-reduced-motion:reduce){
  .gradnum{animation:none}
  .sec-head .eyebrow .dot{animation:none}
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
.pdp-meta .rt{display:inline-flex;align-items:center;gap:5px;color:var(--ink);font-weight:700}
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
GSZ_CSS18

cat > /tmp/gsz18_bump.js <<'GSZ_BUMP18'
const fs=require('fs');
['/opt/gsz/views/partials/store_top.ejs','/opt/gsz/views/partials/store_bottom.ejs'].forEach(function(f){
  let s=fs.readFileSync(f,'utf8');s=s.replace(/(app\.(?:css|js))\?v=\d+/g,'$1?v=18');fs.writeFileSync(f,s);
});
console.log('[ok] asset version -> v=18');
GSZ_BUMP18
node /tmp/gsz18_bump.js || { restore; exit 1; }
echo "[ok] files written"

pm2 restart gsz --update-env >/dev/null
sleep 2
OKALL=1
HEALTH=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health")
HOME_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/")
HB=$(curl -fsS "http://127.0.0.1:$PORT/" || true)
CSS=$(curl -fsS "http://127.0.0.1:$PORT/static/css/app.css?v=18" || true)
[ "$HEALTH" = "200" ]                   || { echo "FAIL: health $HEALTH"; OKALL=0; }
[ "$HOME_CODE" = "200" ]                 || { echo "FAIL: home $HOME_CODE"; OKALL=0; }
grep -q 'app.css?v=18' <<< "$HB"         || { echo "FAIL: version not bumped"; OKALL=0; }
grep -q -- '--paper:#080a14' <<< "$CSS"  || { echo "FAIL: dark theme CSS not served"; OKALL=0; }
grep -q 'overflow-x:clip' <<< "$CSS"     || { echo "FAIL: scrollbar guard missing"; OKALL=0; }
if [ "$OKALL" != "1" ]; then echo "CHECK FAILED — rolling back"; restore; pm2 logs gsz --lines 20 --nostream || true; exit 1; fi
echo "============================================================"
echo "  STEP 18 OK — hard-refresh once (Ctrl+Shift+R)"
echo "  - Premium DARK theme is live across the whole storefront."
echo "  - Horizontal scrollbar removed site-wide."
echo "============================================================"
