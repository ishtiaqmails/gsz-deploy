'use strict';
/* Product page: move "Notify me" onto the plan itself. Each out-of-stock plan pill gets a
   small bell icon (top-right); tapping it joins the waitlist for THAT plan (same /api/waitlist).
   The separate restock-box is hidden. views/product.ejs. Idempotent; aborts if an anchor moved. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_notifybell.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'views/product.ejs');
let s = fs.readFileSync(file, 'utf8');

function edit(name, guard, find, repl) {
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  s = s.slice(0, i) + repl + s.slice(i + find.length);
  console.log('patched: ' + name);
}

/* 1) CSS for the pill bell + hide the old restock box */
const CSS_FIND = ".ppill.oos{opacity:.6} .ppill.oos .ppill-now{text-decoration:line-through;opacity:.6}";
const CSS_ADD = CSS_FIND +
  "\n  .ppill-bell{position:absolute;top:8px;right:8px;width:30px;height:30px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;background:rgba(127,140,180,.14);border:1px solid var(--line-2,rgba(255,255,255,.16));color:var(--ink-soft,#9aa6c0);cursor:pointer;z-index:3;transition:.15s}" +
  "\n  .ppill-bell svg{width:15px;height:15px;stroke:currentColor;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}" +
  "\n  .ppill-bell:hover{border-color:var(--b,#2a7bff);color:var(--b,#2a7bff)}" +
  "\n  .ppill-bell.done{color:#2ad17f;border-color:rgba(42,209,127,.45);background:rgba(42,209,127,.14)}" +
  "\n  .ppill-bell.loading{opacity:.55}" +
  "\n  #restockBox{display:none!important}";
edit('pill-bell css', '.ppill-bell{', CSS_FIND, CSS_ADD);

/* 2) the bell on each out-of-stock pill (added right after the stock label) */
const STOCK_FIND = "<% if (typeof pl.in_stock!=='undefined') { %><span class=\"ppill-stock <%= oos?'out':'in' %>\"><%= oos ? 'Out of stock' : (pl.stock_count>0 ? ('In stock · ' + pl.stock_count + ' left') : 'In stock') %></span><% } %>";
const BELL = "<% if (oos) { %><span class=\"ppill-bell\" data-bell data-pidx=\"<%= pl.idx %>\" data-plabel=\"<%= pl.label %>\" title=\"Notify me when it's back in stock\"><svg viewBox=\"0 0 24 24\"><path d=\"M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9\"/><path d=\"M13.7 21a2 2 0 0 1-3.4 0\"/></svg></span><% } %>";
edit('pill-bell markup', 'class="ppill-bell" data-bell', STOCK_FIND, STOCK_FIND + BELL);

/* 3) one delegated handler (capture phase so the pill isn't also "selected") */
const TRUST_FIND = "<!-- trust row -->";
const SCRIPT =
"<script>\n" +
"(function(){\n" +
"  var IS_CUST=<%= (typeof customer!=='undefined' && customer)?'true':'false' %>;\n" +
"  var SLUG=<%- JSON.stringify(p.slug) %>;\n" +
"  document.addEventListener('click',function(e){\n" +
"    var b=(e.target&&e.target.closest)?e.target.closest('[data-bell]'):null; if(!b) return;\n" +
"    e.preventDefault(); e.stopPropagation();\n" +
"    if(b.classList.contains('done')||b.classList.contains('loading')) return;\n" +
"    if(!IS_CUST){ location.href='/login?next='+encodeURIComponent(location.pathname); return; }\n" +
"    var idx=b.getAttribute('data-pidx')||'', label=b.getAttribute('data-plabel')||'';\n" +
"    b.classList.add('loading');\n" +
"    fetch('/api/waitlist',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'fetch'},credentials:'same-origin',body:'slug='+encodeURIComponent(SLUG)+'&plan='+encodeURIComponent(idx)+'&plan_label='+encodeURIComponent(label)}).then(function(r){return r.json();}).then(function(j){\n" +
"      b.classList.remove('loading');\n" +
"      if(j&&j.ok){ b.classList.add('done'); b.title='We\\u2019ll notify you when it\\u2019s back \\u2713'; b.innerHTML='<svg viewBox=\"0 0 24 24\"><path d=\"M20 6 9 17l-5-5\"/></svg>'; }\n" +
"      else if(j&&j.reason==='login'){ location.href='/login?next='+encodeURIComponent(location.pathname); }\n" +
"      else { b.title='Couldn\\u2019t add you \\u2014 tap to retry'; }\n" +
"    }).catch(function(){ b.classList.remove('loading'); b.title='Network error \\u2014 tap to retry'; });\n" +
"  }, true);\n" +
"})();\n" +
"</script>\n      ";
edit('pill-bell handler', "closest('[data-bell]')", TRUST_FIND, SCRIPT + TRUST_FIND);

fs.writeFileSync(file, s);
console.log('NOTIFY BELL PATCH OK');
