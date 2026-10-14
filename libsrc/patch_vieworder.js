'use strict';
/* "View order" opens the Galaxy Hub modal at that order (phone/desktop model) instead of the
   old /order page. Guests (not logged in) get the Hub sign-in screen. Falls back to /order/<no>
   if the Hub isn't on the page.
   1) hub_model.ejs: expose window.gszOpenOrder(no).
   2) checkout_model.ejs: the View-order link calls it (both success modals), /order as fallback. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_vieworder.js <ROOT>'); process.exit(1); }
const HB = path.join(ROOT, 'views/partials/hub_model.ejs');
const CK = path.join(ROOT, 'views/partials/checkout_model.ejs');

function once(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find); if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}
function replaceAll(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  if (s.indexOf(find) < 0) throw new Error('ANCHOR MISS: ' + name);
  const n = s.split(find).length - 1;
  fs.writeFileSync(file, s.split(find).join(replace));
  console.log('patched: ' + name + ' (' + n + ')');
}

// 1) Hub: window.gszOpenOrder(no)
const OPEN = "function open(tab){ modal.classList.add('on'); window.__gszScrollLock.lock(); setTab(tab||'purchases'); }";
const ADD = OPEN + "\n" +
  "  window.gszOpenOrder=function(no){\n" +
  "    try{ modal.classList.add('on'); window.__gszScrollLock.lock(); }catch(e){}\n" +
  "    try{ tabs.forEach(function(t){ t.classList.toggle('on', t.getAttribute('data-tab')==='purchases'); }); renderFoot(); }catch(e){}\n" +
  "    body.innerHTML='<div class=\"cthm-load\">Loading…</div>';\n" +
  "    loadOrders().then(function(list){\n" +
  "      if(!authed){ signin(); return; }\n" +
  "      var o=(list||[]).filter(function(x){return String(x.order_no)===String(no);})[0];\n" +
  "      if(o){ detail(o); } else { pur(list); }\n" +
  "    }).catch(function(){ try{ pur(cache||[]); }catch(e){} });\n" +
  "    return true;\n" +
  "  };";
once(HB, 'hub:open-order', 'window.gszOpenOrder=function', OPEN, ADD);

// 2) checkout: View-order link opens the Hub (both success modals), /order fallback
replaceAll(CK, 'checkout:view-order', 'window.gszOpenOrder(',
  "href=\"/order/'+encodeURIComponent(no)+'\">View order '+esc(no)+'</a>",
  "href=\"/order/'+encodeURIComponent(no)+'\" onclick=\"return !(window.gszOpenOrder&&window.gszOpenOrder(\\''+no+'\\'))\">View order '+esc(no)+'</a>");

console.log('VIEWORDER PATCH OK');
