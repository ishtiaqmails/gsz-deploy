'use strict';
/* patch_pdplibrary.js — two in-place, idempotent edits to LIVE files:
   1) routes/checkout.js  — require sign-in on GET /checkout (guests -> /login?next=…).
      Covers the product-page "Buy now" link, which points straight at /checkout.
   2) views/product.ejs   — add a "What's Inside" tab to IPTV product pages that pulls the
      live library summary (counts + categories/countries) and links to the full /library.
   Safe to run repeatedly: each edit is skipped if its marker is already present.
   Anchors are the most stable strings in each file; aborts loudly if an anchor is missing. */
const fs = require('fs');
const GSZ = '/opt/gsz';
let changed = [];

/* ---------- 1) checkout sign-in gate ---------- */
(function () {
  const p = GSZ + '/routes/checkout.js';
  let s = fs.readFileSync(p, 'utf8');
  if (s.indexOf('SIGNIN_GATE_v1') !== -1) { console.log('   checkout.js: gate already present — skip'); return; }
  const anchor = "router.get('/checkout', async (req, res) => {";
  if (s.indexOf(anchor) === -1) throw new Error('checkout.js: GET /checkout anchor not found');
  const gate = anchor + "\n    /* SIGNIN_GATE_v1 — checkout requires an account; guests sign in and return here */\n"
    + "    if (!(req.session && req.session.customer)) return res.redirect('/login?next=' + encodeURIComponent(req.originalUrl || '/checkout'));";
  s = s.replace(anchor, gate);
  fs.writeFileSync(p, s);
  changed.push('routes/checkout.js');
  console.log('   checkout.js: sign-in gate added');
})();

/* ---------- 2) product page "What's Inside" ---------- */
(function () {
  const p = GSZ + '/views/product.ejs';
  let s = fs.readFileSync(p, 'utf8');
  if (s.indexOf('data-tab="library"') !== -1) { console.log('   product.ejs: What\'s Inside already present — skip'); return; }

  // (a) tab button — before the Reviews tab
  const tabAnchor = '<button class="ptab" data-tab="reviews"';
  if (s.indexOf(tabAnchor) === -1) throw new Error('product.ejs: reviews tab anchor not found');
  const tabBtn = "<% if (p.cat_slug==='iptv') { %><button class=\"ptab\" data-tab=\"library\" type=\"button\">What's Inside</button><% } %>\n        ";
  s = s.replace(tabAnchor, tabBtn + tabAnchor);

  // (b) tab panel — before the Reviews panel
  const panelAnchor = '<div class="ptab-panel" data-panel="reviews">';
  if (s.indexOf(panelAnchor) === -1) throw new Error('product.ejs: reviews panel anchor not found');
  const panel =
    "<% if (p.cat_slug==='iptv') { %>\n"
    + "      <div class=\"ptab-panel wi\" data-panel=\"library\" id=\"wiPanel\" data-slug=\"<%= p.slug %>\">\n"
    + "        <div class=\"wi-load\">Loading the live library…</div>\n"
    + "      </div>\n"
    + "      <% } %>\n      ";
  s = s.replace(panelAnchor, panel + panelAnchor);

  // (c) styles — appended to the product page's first <style> block
  const styleAnchor = '</style>';
  if (s.indexOf(styleAnchor) === -1) throw new Error('product.ejs: </style> anchor not found');
  const css =
    "\n  /* What's Inside — live IPTV library reflection */\n"
    + "  .wi .wi-load{color:var(--muted,#9aa6c0);padding:14px 2px;font-size:14px}\n"
    + "  .wi-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:2px 0 14px}\n"
    + "  @media(max-width:560px){.wi-grid{grid-template-columns:repeat(2,1fr)}}\n"
    + "  .wi-tile{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.10);border-radius:14px;padding:14px 12px;text-align:center}\n"
    + "  .wi-tile b{display:block;font-size:22px;font-weight:800;letter-spacing:-.02em;line-height:1.1}\n"
    + "  .wi-tile span{display:block;margin-top:3px;font-size:11.5px;color:var(--muted,#9aa6c0);text-transform:uppercase;letter-spacing:.06em}\n"
    + "  .wi-meta{color:var(--muted,#9aa6c0);font-size:13.5px;margin:0 0 14px}\n"
    + "  .wi-chips{display:flex;flex-wrap:wrap;gap:7px;margin:0 0 16px}\n"
    + "  .wi-chip{font-size:12px;font-weight:600;padding:5px 11px;border-radius:999px;background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.10);color:#e7ebf5}\n"
    + "  .wi-browse{display:inline-flex;align-items:center;gap:8px;font-weight:700;font-size:14px;text-decoration:none;color:#fff;background:linear-gradient(135deg,var(--g1,#2f7bff),var(--g2,#29d3ff));padding:11px 18px;border-radius:12px}\n"
    + "  .wi-browse svg{width:16px;height:16px;stroke:currentColor;fill:none;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round}\n";
  s = s.replace(styleAnchor, css + styleAnchor);

  // (d) loader script — standalone, lazy (loads when the tab is first opened)
  const scriptAnchor = "<%- include('partials/store_bottom') %>";
  if (s.indexOf(scriptAnchor) === -1) throw new Error('product.ejs: store_bottom include anchor not found');
  const script =
    "<script>\n"
    + "(function(){\n"
    + "  var panel=document.getElementById('wiPanel'); if(!panel) return;\n"
    + "  var slug=panel.getAttribute('data-slug')||''; var done=false;\n"
    + "  function fmt(n){ n=Number(n||0); return n>=1000?(n>=1000000?(n/1000000).toFixed(1).replace(/\\.0$/,'')+'M':(Math.round(n/100)/10).toFixed(1).replace(/\\.0$/,'')+'K'):String(n); }\n"
    + "  function esc(t){var d=document.createElement('div');d.textContent=(t==null?'':String(t));return d.innerHTML;}\n"
    + "  function keys(o){ var m={}; ['live','vod','series'].forEach(function(k){ var c=o&&o[k]&&o[k].categories; if(c) Object.keys(c).forEach(function(x){ m[x]=(m[x]||0)+c[x]; }); }); return m; }\n"
    + "  function ckeys(o){ var m={}; ['live','vod','series'].forEach(function(k){ var c=o&&o[k]&&o[k].countries; if(c) Object.keys(c).forEach(function(x){ m[x]=(m[x]||0)+c[x]; }); }); return m; }\n"
    + "  function load(){ if(done) return; done=true;\n"
    + "    fetch('/iptv/'+encodeURIComponent(slug)+'/summary.json',{headers:{'X-Requested-With':'fetch'},credentials:'same-origin'}).then(function(r){return r.json();}).then(function(j){\n"
    + "      if(!j||!j.ok||!j.server){ panel.innerHTML='<div class=\"wi-load\">Library is being prepared for this service — check back shortly.</div>'; return; }\n"
    + "      var s=j.server; var cats=keys(s.categories), countries=ckeys(s.categories);\n"
    + "      var nCat=Object.keys(cats).length, nCo=Object.keys(countries).filter(function(c){return c&&c!=='Worldwide';}).length;\n"
    + "      var topCo=Object.keys(countries).filter(function(c){return c&&c!=='Worldwide';}).sort(function(a,b){return countries[b]-countries[a];}).slice(0,8);\n"
    + "      var h='<div class=\"wi-grid\">'\n"
    + "        +'<div class=\"wi-tile\"><b>'+fmt(s.live_count)+'</b><span>Live TV</span></div>'\n"
    + "        +'<div class=\"wi-tile\"><b>'+fmt(s.vod_count)+'</b><span>Movies</span></div>'\n"
    + "        +'<div class=\"wi-tile\"><b>'+fmt(s.series_count)+'</b><span>Series</span></div>'\n"
    + "        +'<div class=\"wi-tile\"><b>'+fmt(s.episode_count)+'</b><span>Episodes</span></div></div>';\n"
    + "      var bits=[]; if(nCat) bits.push(nCat+' categories'); if(nCo) bits.push(nCo+' countries'); if(bits.length) h+='<p class=\"wi-meta\">'+bits.join(' \\u00b7 ')+'</p>';\n"
    + "      if(topCo.length){ h+='<div class=\"wi-chips\">'+topCo.map(function(c){return '<span class=\"wi-chip\">'+esc(c)+'</span>';}).join('')+'</div>'; }\n"
    + "      h+='<a class=\"wi-browse\" href=\"/library/'+encodeURIComponent(slug)+'\">Browse the full library <svg viewBox=\"0 0 24 24\"><path d=\"M5 12h14\"/><path d=\"M13 6l6 6-6 6\"/></svg></a>';\n"
    + "      panel.innerHTML=h;\n"
    + "    }).catch(function(){ panel.innerHTML='<div class=\"wi-load\">Couldn\\u2019t load the library right now.</div>'; });\n"
    + "  }\n"
    + "  var tab=document.querySelector('.ptab[data-tab=\"library\"]'); if(tab) tab.addEventListener('click',load);\n"
    + "  if(panel.classList.contains('on')) load();\n"
    + "})();\n"
    + "</script>\n";
  s = s.replace(scriptAnchor, script + scriptAnchor);

  fs.writeFileSync(p, s);
  changed.push('views/product.ejs');
  console.log('   product.ejs: What\'s Inside tab added');
})();

/* ---------- 3) de-market already-deployed What's Inside copy ---------- */
(function () {
  const p = GSZ + '/views/product.ejs';
  let s = fs.readFileSync(p, 'utf8'); const before = s;
  const oldLine = "      h+='<p class=\"wi-meta\">A fully loaded library'+(nCat?(' across <b>'+nCat+'</b> categories'):'')+(nCo?(' and <b>'+nCo+'</b> countries'):'')+' — organised, premium and updated automatically.</p>';";
  const newLine = "      var bits=[]; if(nCat) bits.push(nCat+' categories'); if(nCo) bits.push(nCo+' countries'); if(bits.length) h+='<p class=\"wi-meta\">'+bits.join(' · ')+'</p>';";
  if (s.indexOf(oldLine) !== -1) { s = s.replace(oldLine, newLine); fs.writeFileSync(p, s); if (changed.indexOf('views/product.ejs') === -1) changed.push('views/product.ejs'); console.log('   product.ejs: de-marketed What\'s Inside copy'); }
})();

console.log('PATCH OK' + (changed.length ? ' — changed: ' + changed.join(', ') : ' — nothing to change'));
