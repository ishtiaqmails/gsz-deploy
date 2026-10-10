'use strict';
/* The hamburger drawer is built by JS (app.js buildDrawerCats() fills #drawerCats from CATS on load),
   which is why editing the EJS template never changed it. Replace that function so the drawer renders
   PAGES (Track, Resellers, About, FAQ, WhatsApp Channel, My Account) instead of duplicating the
   categories that already live on the Store tab. Reuses the drawer's own .dcat/.cg styling. Idempotent. */
const fs = require('fs');
const file = process.argv[2];
if (!file) { console.error('usage: node patch_appjs.js <app.js path>'); process.exit(1); }
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('gsz-drawer-pages') >= 0) { console.log('skip (already): drawer pages present'); console.log('APPJS PATCH OK'); process.exit(0); }

const sig = 'function buildDrawerCats()';
const i = s.indexOf(sig);
if (i < 0) throw new Error('ANCHOR MISS: buildDrawerCats() not found in app.js');
const braceStart = s.indexOf('{', i);
if (braceStart < 0) throw new Error('ANCHOR MISS: buildDrawerCats body');
let depth = 0, end = -1;
for (let j = braceStart; j < s.length; j++) { if (s[j] === '{') depth++; else if (s[j] === '}') { depth--; if (depth === 0) { end = j; break; } } }
if (end < 0) throw new Error('ANCHOR MISS: unbalanced buildDrawerCats body');

const NEWFN =
"function buildDrawerCats(){ /* gsz-drawer-pages */ var el=document.getElementById('drawerCats'); if(!el) return; " +
"var P=[" +
"['/track','Track an Order','#2a6cff','#19c6ee','<path d=\\\"M3 7h13l5 5v5h-2\\\"/><path d=\\\"M3 7v10h2\\\"/><circle cx=\\\"7.5\\\" cy=\\\"17.5\\\" r=\\\"2\\\"/><circle cx=\\\"17.5\\\" cy=\\\"17.5\\\" r=\\\"2\\\"/>']," +
"['/resellers','Reseller Panels','#7a2bff','#c23bff','<path d=\\\"M3 21V9l9-6 9 6v12\\\"/><path d=\\\"M9 21v-6h6v6\\\"/>']," +
"['/about','About Us','#2a6cff','#5b8bff','<circle cx=\\\"12\\\" cy=\\\"12\\\" r=\\\"9\\\"/><path d=\\\"M12 11v5M12 8h.01\\\"/>']," +
"['/faq','FAQ & Policies','#19c6ee','#2a6cff','<circle cx=\\\"12\\\" cy=\\\"12\\\" r=\\\"9\\\"/><path d=\\\"M9.6 9a2.4 2.4 0 1 1 3.4 2.2c-.8.4-1 .9-1 1.8M12 17h.01\\\"/>']," +
"['https://whatsapp.com/channel/0029VbDvVgCDOQIbbuzNiF11','WhatsApp Channel','#1fb457','#19c6ee','<path d=\\\"M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z\\\"/>']," +
"['/account','My Account','#5b8bff','#2a6cff','<circle cx=\\\"12\\\" cy=\\\"8\\\" r=\\\"4\\\"/><path d=\\\"M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7\\\"/>']" +
"]; el.innerHTML=P.map(function(p){ var ext=/^http/.test(p[0])?' target=\"_blank\" rel=\"noopener\"':''; " +
"return '<a class=\"dcat\" href=\"'+p[0]+'\"'+ext+' style=\"--g1:'+p[2]+';--g2:'+p[3]+'\"><span class=\"cg\"><svg class=\"ic\" viewBox=\"0 0 24 24\">'+p[4]+'</svg></span><span><b>'+p[1]+'</b></span></a>'; }).join(''); }";

s = s.slice(0, i) + NEWFN + s.slice(end + 1);
fs.writeFileSync(file, s);
console.log('patched: buildDrawerCats() now renders pages (Track/Resellers/About/FAQ/Channel/My Account)');
console.log('APPJS PATCH OK');
