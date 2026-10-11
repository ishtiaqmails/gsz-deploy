'use strict';
/* Admin mobile app model: on phones/touch tablets the admin gets a fixed bottom nav bar
   (Home · Products · Orders · Pay · Menu) — "Menu" opens the full section drawer. Desktop keeps the
   sidebar exactly as-is. Patches views/admin/_shell_top.ejs (CSS) + _shell_bottom.ejs (the bar).
   Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_adminapp.js <ROOT>'); process.exit(1); }

/* ---- _shell_top.ejs : CSS ---- */
(function(){
  const file = path.join(ROOT, 'views/admin/_shell_top.ejs');
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf('/*admin-app-model*/') >= 0) { console.log('shell_top: css present (skip)'); return; }
  const CSS =
"\n/*admin-app-model*/\n" +
".mbar{display:none}\n" +
"@media(max-width:880px){\n" +
"  .mtoggle{display:none!important}\n" +
"  .tbar{padding-left:16px}\n" +
"  .content{padding-bottom:88px!important}\n" +
"  .mbar{display:grid;grid-template-columns:repeat(5,1fr);position:fixed;left:0;right:0;bottom:0;z-index:50;background:rgba(255,255,255,.96);backdrop-filter:blur(12px);border-top:1px solid var(--hair);padding:6px 4px calc(6px + env(safe-area-inset-bottom));box-shadow:0 -10px 28px -18px rgba(15,24,54,.4)}\n" +
"  .mbar a,.mbar button{display:flex;flex-direction:column;align-items:center;gap:3px;border:0;background:none;color:var(--muted);font:inherit;font-size:10.5px;font-weight:700;padding:6px 2px;cursor:pointer;border-radius:10px;text-decoration:none}\n" +
"  .mbar a.on,.mbar button.on{color:var(--brand)}\n" +
"  .mbar a.on svg,.mbar button.on svg{stroke:var(--brand)}\n" +
"  .mbar svg{width:21px;height:21px;stroke:currentColor;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}\n" +
"  body.nav-open .side{z-index:60}\n" +
"  body.nav-open .scrim2{z-index:55}\n" +
"}\n";
  const ANCH = "</style>\n</head>";
  if (s.indexOf(ANCH) >= 0) { s = s.replace(ANCH, CSS + "</style>\n</head>"); fs.writeFileSync(file, s); console.log('shell_top: app-model css added'); }
  else { console.log('shell_top: anchor missing (skip)'); }
})();

/* ---- _shell_bottom.ejs : the bottom bar ---- */
(function(){
  const file = path.join(ROOT, 'views/admin/_shell_bottom.ejs');
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf('class="mbar"') >= 0) { console.log('shell_bottom: bar present (skip)'); return; }
  const BAR =
'<nav class="mbar" aria-label="Primary">\n' +
'  <a href="/admin" class="<%= (typeof active!==\'undefined\'&&active===\'dashboard\')?\'on\':\'\' %>"><svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg><span>Home</span></a>\n' +
'  <a href="/admin/products" class="<%= (typeof active!==\'undefined\'&&active===\'products\')?\'on\':\'\' %>"><svg viewBox="0 0 24 24"><path d="M3 7l9-4 9 4-9 4-9-4z"/><path d="M3 7v10l9 4 9-4V7"/><path d="M12 11v10"/></svg><span>Products</span></a>\n' +
'  <a href="/admin/orders" class="<%= (typeof active!==\'undefined\'&&active===\'orders\')?\'on\':\'\' %>"><svg viewBox="0 0 24 24"><path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><path d="M3 6h18"/><path d="M16 10a4 4 0 0 1-8 0"/></svg><span>Orders</span></a>\n' +
'  <a href="/admin/payments" class="<%= (typeof active!==\'undefined\'&&active===\'payments\')?\'on\':\'\' %>"><svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20"/></svg><span>Pay</span></a>\n' +
'  <button type="button" onclick="document.body.classList.toggle(\'nav-open\')"><svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h16"/></svg><span>Menu</span></button>\n' +
'</nav>\n';
  const ANCH = "<script>/*gsz_adm_scroll*/";
  if (s.indexOf(ANCH) >= 0) { s = s.replace(ANCH, BAR + ANCH); fs.writeFileSync(file, s); console.log('shell_bottom: bottom bar added'); }
  else { console.log('shell_bottom: anchor missing (skip)'); }
})();

console.log('ADMINAPP OK');
