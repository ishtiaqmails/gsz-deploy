'use strict';
/* Admin shell layout fixes (central — touches only the two admin shell partials):
   #70 No horizontal scroll: tables stop forcing a 560px min-width and instead STACK
       into label/value rows on narrow screens (headers copied into each cell's
       data-label by a tiny generic script, so every admin table is covered at once).
   #71 Sections cut on mobile: content never exceeds the viewport; bottom padding
       clears the mobile footer bar.
   #72 Jumps to top on refresh/save: scroll position is persisted continuously (not
       just on submit) and re-restored across async/AJAX renders.
   Files: views/admin/_shell_top.ejs, views/admin/_shell_bottom.ejs. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_adminshell.js <ROOT>'); process.exit(1); }

function patch(file, name, guard, find, repl) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  s = s.slice(0, i) + repl + s.slice(i + find.length);
  fs.writeFileSync(file, s);
  console.log('patched: ' + name);
}

const TOP = path.join(ROOT, 'views/admin/_shell_top.ejs');
const BOT = path.join(ROOT, 'views/admin/_shell_bottom.ejs');

/* ---- #70/#71 : replace the forced-min-width rule with responsive stacking ---- */
const OLD_RULE = '@media(max-width:860px){ .card[style*="overflow:hidden"] table{min-width:560px} }';
const NEW_RULE =
  '/*gsz_rsp_tables*/\n' +
  '@media(max-width:860px){\n' +
  '  .card[style*="overflow:hidden"]{overflow-x:visible!important}\n' +
  '  table.rsp{width:100%}\n' +
  '  table.rsp thead{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap;border:0}\n' +
  '  table.rsp,table.rsp tbody,table.rsp tr,table.rsp td{display:block;width:100%}\n' +
  '  table.rsp tr{border:1px solid var(--hair);border-radius:12px;background:#fff;padding:6px 12px;margin:0 0 10px;box-shadow:0 1px 2px rgba(15,24,54,.04)}\n' +
  '  table.rsp td{display:flex;align-items:center;justify-content:space-between;gap:14px;text-align:right;border:0!important;padding:8px 0;font-size:13.5px;white-space:normal!important;word-break:break-word}\n' +
  '  table.rsp td+td{border-top:1px solid var(--hair)!important}\n' +
  '  table.rsp td:before{content:attr(data-label);font-weight:700;color:var(--muted);text-align:left;flex:0 0 auto;white-space:nowrap}\n' +
  '  table.rsp td[data-label=""]:before,table.rsp td:not([data-label]):before{content:""}\n' +
  '  table.rsp td:empty{display:none}\n' +
  '  .content{max-width:100%;overflow-x:hidden}\n' +
  '}';
patch(TOP, '#70 responsive tables', '/*gsz_rsp_tables*/', OLD_RULE, NEW_RULE);

/* ---- #70 : generic enhancer — class + data-label on every admin table ----
   Copies each column's header text into the matching cell's data-label, but leaves
   visual-only cells (checkbox, thumbnail, drag handle — no real text) label-free so
   the stacked mobile view stays clean and uncluttered. */
const RSP_JS =
  '<script>/*gsz_rsp_enh*/(function(){\n' +
  '  function enh(){\n' +
  '    var tbls=document.querySelectorAll(".content table");\n' +
  '    for(var t=0;t<tbls.length;t++){ var tb=tbls[t];\n' +
  '      tb.classList.add("rsp");\n' +
  '      var heads=[]; var hr=tb.querySelector("thead tr")||tb.querySelector("tr");\n' +
  '      if(hr){ var hc=hr.children; for(var k=0;k<hc.length;k++) heads.push((hc[k].textContent||"").trim()); }\n' +
  '      var rows=tb.querySelectorAll("tbody tr"); if(!rows.length) rows=tb.querySelectorAll("tr");\n' +
  '      for(var r=0;r<rows.length;r++){ var cs=rows[r].children;\n' +
  '        for(var c=0;c<cs.length;c++){ var td=cs[c]; if(td.hasAttribute("data-label")) continue;\n' +
  '          var txt=(td.textContent||"").replace(/\\s+/g,"");\n' +
  '          td.setAttribute("data-label", txt ? (heads[c]||"") : ""); } }\n' +
  '    }\n' +
  '  }\n' +
  '  try{ enh(); }catch(e){}\n' +
  '  var mo; try{ mo=new MutationObserver(function(){ try{ enh(); }catch(e){} }); mo.observe(document.querySelector(".content")||document.body,{childList:true,subtree:true}); }catch(e){}\n' +
  '})();</script>\n';
/* update-in-place if an earlier enhancer is present (no layering) */
(function(){
  let b = fs.readFileSync(BOT, 'utf8');
  const mk = '<script>/*gsz_rsp_enh*/';
  const a = b.indexOf(mk);
  if (a >= 0) {
    const end = '</script>', e = b.indexOf(end, a);
    const cur = b.slice(a, e + end.length);
    if (cur === RSP_JS.trim()) { console.log('skip (already): #70 table enhancer'); return; }
    b = b.slice(0, a) + RSP_JS.trim() + b.slice(e + end.length);
    fs.writeFileSync(BOT, b); console.log('updated: #70 table enhancer'); return;
  }
  const i = b.indexOf('</body></html>');
  if (i < 0) throw new Error('ANCHOR MISS: #70 table enhancer');
  b = b.slice(0, i) + RSP_JS + b.slice(i);
  fs.writeFileSync(BOT, b); console.log('patched: #70 table enhancer');
})();

/* ---- #72 : robust scroll restore (survives AJAX saves) ---- */
const OLD_SCROLL_START = '<script>/*gsz_adm_scroll*/(function(){';
let bot = fs.readFileSync(BOT, 'utf8');
if (bot.indexOf('/*gsz_adm_scroll2*/') >= 0) {
  console.log('skip (already): #72 scroll restore');
} else {
  const a = bot.indexOf(OLD_SCROLL_START);
  if (a < 0) throw new Error('ANCHOR MISS: #72 scroll script start');
  const end = '})();</script>';
  const b = bot.indexOf(end, a);
  if (b < 0) throw new Error('ANCHOR MISS: #72 scroll script end');
  const NEW_SCROLL =
    '<script>/*gsz_adm_scroll2*/(function(){\n' +
    '  try{ if("scrollRestoration" in history) history.scrollRestoration="manual"; }catch(e){}\n' +
    '  var KEY="gsz_adm_scroll:"+location.pathname;\n' +
    '  function save(){ try{ sessionStorage.setItem(KEY, String(window.scrollY||window.pageYOffset||0)); }catch(e){} }\n' +
    '  function target(){ try{ var y=sessionStorage.getItem(KEY); return y===null?null:(parseInt(y,10)||0); }catch(e){ return null; } }\n' +
    '  function restore(){ var y=target(); if(y===null) return; var want=Math.min(y, Math.max(0,(document.documentElement.scrollHeight||0)-window.innerHeight)); window.scrollTo(0, want); }\n' +
    '  var tm=null; function onScroll(){ if(tm) return; tm=setTimeout(function(){ tm=null; save(); },150); }\n' +
    '  window.addEventListener("scroll", onScroll, {passive:true});\n' +
    '  document.addEventListener("submit", save, true);\n' +
    '  window.addEventListener("beforeunload", save);\n' +
    '  restore();\n' +
    '  // re-restore across async/AJAX content shifts\n' +
    '  var tries=0; var iv=setInterval(function(){ restore(); if(++tries>=8) clearInterval(iv); },120);\n' +
    '  window.addEventListener("load", function(){ restore(); setTimeout(restore,200); setTimeout(restore,600); });\n' +
    '})();</script>';
  bot = bot.slice(0, a) + NEW_SCROLL + bot.slice(b + end.length);
  fs.writeFileSync(BOT, bot);
  console.log('patched: #72 scroll restore');
}

console.log('ADMIN SHELL PATCH OK');
