'use strict';
/* Meta Pixel install.
   Part A: base pixel before </head> on every customer-facing head file.
   Part B: Purchase event before </body> on the order-confirmation page (order.ejs),
           fired once per order (localStorage, falls back to sessionStorage) and only on a
           paid/confirmed status, using the order's real paid amount + currency (Rs -> PKR).
   Guarded + idempotent. Admin pages are intentionally NOT tracked. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_metapixel.js <ROOT>'); process.exit(1); }
const PIXEL_ID = '1765880738032271';

const BASE =
'<!-- Meta Pixel Code -->\n' +
'<script>\n' +
'!function(f,b,e,v,n,t,s)\n' +
'{if(f.fbq)return;n=f.fbq=function(){n.callMethod?\n' +
'n.callMethod.apply(n,arguments):n.queue.push(arguments)};\n' +
'if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version=\'2.0\';\n' +
'n.queue=[];t=b.createElement(e);t.async=!0;\n' +
't.src=v;s=b.getElementsByTagName(e)[0];\n' +
's.parentNode.insertBefore(t,s)}(window, document,\'script\',\n' +
'\'https://connect.facebook.net/en_US/fbevents.js\');\n' +
'fbq(\'init\', \'' + PIXEL_ID + '\');\n' +
'fbq(\'track\', \'PageView\');\n' +
'</script>\n' +
'<noscript><img height="1" width="1" style="display:none"\n' +
'src="https://www.facebook.com/tr?id=' + PIXEL_ID + '&ev=PageView&noscript=1"/></noscript>\n' +
'<!-- End Meta Pixel Code -->\n';

const BASE_GUARD = "fbq('init', '" + PIXEL_ID + "')";

const HEAD_FILES = [
  'views/partials/store_top.ejs',
  'views/partials/dash_top.ejs',
  'views/order.ejs',
  'views/invoice.ejs',
  'views/notfound.ejs'
];

function insertBefore(file, anchor, block, guard, name) {
  const p = path.join(ROOT, file);
  if (!fs.existsSync(p)) { console.log('skip (missing): ' + file); return; }
  let s = fs.readFileSync(p, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already ' + name + '): ' + file); return; }
  const i = s.indexOf(anchor);
  if (i < 0) { console.log('MISS (' + anchor + ' not found): ' + file); return; }
  fs.writeFileSync(p, s.slice(0, i) + block + s.slice(i));
  console.log('patched (' + name + '): ' + file);
}

/* Part A — base pixel before </head> */
HEAD_FILES.forEach(function (f) { insertBefore(f, '</head>', BASE + '\n', BASE_GUARD, 'base'); });

/* Part B — Purchase before </body> on order.ejs */
const PURCHASE =
'<% var _fbPaid = [\'paid\',\'approved\',\'delivering\',\'delivered\'].indexOf(String(o.status)) >= 0; %>\n' +
'<% if (_fbPaid) { %>\n' +
'<!-- Meta Pixel Purchase -->\n' +
'<script>\n' +
'(function(){\n' +
'  var k=\'fb_purchase_<%= o.order_no %>\', fired=false;\n' +
'  try{ if(localStorage.getItem(k)){fired=true;}else{localStorage.setItem(k,\'1\');} }\n' +
'  catch(e){ try{ if(sessionStorage.getItem(k)){fired=true;}else{sessionStorage.setItem(k,\'1\');} }catch(e2){} }\n' +
'  if(!fired && window.fbq){ fbq(\'track\',\'Purchase\',{value: <%= Number(o.amount_display)||0 %>, currency: \'<%= (o.currency==="Rs")?"PKR":(o.currency||"PKR") %>\'}); }\n' +
'})();\n' +
'</script>\n' +
'<!-- End Meta Pixel Purchase -->\n' +
'<% } %>\n';

insertBefore('views/order.ejs', '</body>', PURCHASE, 'fb_purchase_', 'purchase');

console.log('META PIXEL PATCH OK');
