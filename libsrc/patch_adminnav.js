'use strict';
/* Admin nav reorg + mobile footer redesign.
   - views/admin/_shell_top.ejs: rebuild the sidebar nav into clean categories,
     drop the duplicate "WhatsApp bot" (/admin/wabot) link. Replaces everything
     between the on() marker and </nav>, so it is whitespace-robust.
   - views/admin/_shell_bottom.ejs: footer bar -> Home / Orders / Reports / Products / Menu.
   Idempotent; aborts if a marker is missing. Routes are untouched (links only). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_adminnav.js <ROOT>'); process.exit(1); }

const SVG = {
  dashboard: '<svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>',
  reports: '<svg viewBox="0 0 24 24"><path d="M3 3v18h18"/><rect x="7" y="11" width="3" height="7"/><rect x="12" y="7" width="3" height="11"/><rect x="17" y="4" width="3" height="14"/></svg>',
  products: '<svg viewBox="0 0 24 24"><path d="M3 7l9-4 9 4-9 4-9-4z"/><path d="M3 7v10l9 4 9-4V7"/><path d="M12 11v10"/></svg>',
  categories: '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="4" rx="1"/><rect x="3" y="11" width="18" height="4" rx="1"/><rect x="3" y="18" width="12" height="4" rx="1"/></svg>',
  orders: '<svg viewBox="0 0 24 24"><path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><path d="M3 6h18"/><path d="M16 10a4 4 0 0 1-8 0"/></svg>',
  payments: '<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20"/></svg>',
  issues: '<svg viewBox="0 0 24 24"><path d="M10.3 3.9 2 18a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>',
  trials: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3.2"/><path d="M12 2v3"/><path d="M12 19v3"/><path d="M2 12h3"/><path d="M19 12h3"/></svg>',
  netflix: '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="m8 8 8 8"/><path d="m16 8-8 8"/></svg>',
  inventory: '<svg viewBox="0 0 24 24"><path d="M3 7l9-4 9 4-9 4-9-4z"/><path d="M3 7v10l9 4 9-4V7"/><path d="M12 11v10"/></svg>',
  customers: '<svg viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
  whatsapp: '<svg viewBox="0 0 24 24"><path d="M21 11.5a8.4 8.4 0 0 1-1.2 4.4L21 21l-5.3-1.4A8.5 8.5 0 1 1 21 11.5Z"/><path d="m8.5 12 2 2 4-4.2"/></svg>',
  messages: '<svg viewBox="0 0 24 24"><path d="M4 5h16v10H9l-4 4V5z"/></svg>',
  announcements: '<svg viewBox="0 0 24 24"><path d="M3 11l18-5v12L3 14z"/><path d="M11.6 16.8a3 3 0 0 1-5.8-1.6"/></svg>',
  coupons: '<svg viewBox="0 0 24 24"><path d="M4 9V6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v3a2 2 0 0 0 0 6v3a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-3a2 2 0 0 0 0-6z"/><path d="M9 9v6"/></svg>',
  reviews: '<svg viewBox="0 0 24 24"><path d="m12 2 2.6 6.3L21 9l-5 4.3L17.5 20 12 16.5 6.5 20 8 13.3 3 9l6.4-.7L12 2Z"/></svg>',
  marketing: '<svg viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/></svg>',
  branding: '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="14" rx="2"/><path d="m3 14 5-4 4 3 4-5 5 6"/></svg>',
  content: '<svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h10"/></svg>',
  cs_dash: '<svg viewBox="0 0 24 24"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>',
  cs_posts: '<svg viewBox="0 0 24 24"><path d="M8 3h8l4 4v14H4V3z"/><path d="M8 9h8M8 13h8M8 17h5"/></svg>',
  cs_import: '<svg viewBox="0 0 24 24"><path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/></svg>',
  cs_redirects: '<svg viewBox="0 0 24 24"><path d="M3 7h12l-3-3"/><path d="M21 17H9l3 3"/></svg>'
};
function link(key, href, label) { return '    <a href="' + href + '" class="<%= on(\'' + key + '\') %>">' + SVG[key] + label + '</a>'; }
const GROUPS = [
  ['Overview', [['dashboard', '/admin', 'Dashboard'], ['reports', '/admin/reports', 'Reports']]],
  ['Catalog', [['products', '/admin/products', 'Products'], ['categories', '/admin/categories', 'Categories']]],
  ['Sales', [['orders', '/admin/orders', 'Orders'], ['payments', '/admin/payments', 'Payments'], ['issues', '/admin/issues', 'Issues']]],
  ['Fulfilment', [['trials', '/admin/trials', 'Trials'], ['netflix', '/admin/netflix', 'Netflix'], ['inventory', '/admin/inventory', 'Inventory']]],
  ['Customers &amp; Messaging', [['customers', '/admin/customers', 'Customers'], ['whatsapp', '/admin/whatsapp', 'WhatsApp'], ['messages', '/admin/messages', 'Bot messages'], ['announcements', '/admin/announcements', 'Announcements']]],
  ['Marketing', [['coupons', '/admin/coupons', 'Discount codes'], ['reviews', '/admin/reviews', 'Reviews'], ['marketing', '/admin/marketing', 'Marketing']]],
  ['Storefront', [['branding', '/admin/branding', 'Branding &amp; Banners'], ['content', '/admin/content', 'Marquee &amp; stats']]],
  ['Content Studio', [['cs_dash', '/admin/cstudio', 'Overview'], ['cs_posts', '/admin/cstudio/posts', 'Posts'], ['cs_import', '/admin/cstudio/import', 'Import'], ['cs_redirects', '/admin/cstudio/redirects', 'Redirects']]]
];
function buildNav() {
  const out = [];
  for (const [grp, items] of GROUPS) {
    out.push('    <div class="grp">' + grp + '</div>');
    for (const [k, h, l] of items) out.push(link(k, h, l));
  }
  return out.join('\n');
}

// ---- _shell_top.ejs: rebuild nav between on() marker and </nav> ----
(function () {
  const file = path.join(ROOT, 'views/admin/_shell_top.ejs');
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf('Customers &amp; Messaging') >= 0) { console.log('nav: already reorganized (skip)'); return; }
  const START = "<% function on(x){ return (typeof active!=='undefined'&&active===x)?'on':'' } %>";
  const a = s.indexOf(START); if (a < 0) throw new Error('nav START marker missing');
  const b = s.indexOf('</nav>', a); if (b < 0) throw new Error('nav END marker missing');
  s = s.slice(0, a + START.length) + '\n' + buildNav() + '\n  ' + s.slice(b);
  fs.writeFileSync(file, s);
  console.log('nav: reorganized (8 groups, WhatsApp bot removed)');
})();

// ---- _shell_bottom.ejs: footer bar ----
(function () {
  const file = path.join(ROOT, 'views/admin/_shell_bottom.ejs');
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf('>Reports</span>') >= 0) { console.log('footer: already updated (skip)'); return; }
  const START = '<nav class="mbar" aria-label="Primary">';
  const a = s.indexOf(START); if (a < 0) throw new Error('footer START marker missing');
  const b = s.indexOf('</nav>', a); if (b < 0) throw new Error('footer END marker missing');
  function fa(key, href, label) { return '  <a href="' + href + '" class="<%= (typeof active!==\'undefined\'&&active===\'' + key + '\')?\'on\':\'\' %>">' + SVG[key] + '<span>' + label + '</span></a>'; }
  const bar = [
    fa('dashboard', '/admin', 'Home'),
    fa('orders', '/admin/orders', 'Orders'),
    fa('reports', '/admin/reports', 'Reports'),
    fa('products', '/admin/products', 'Products'),
    '  <button type="button" onclick="document.body.classList.toggle(\'nav-open\')"><svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h16"/></svg><span>Menu</span></button>'
  ].join('\n');
  s = s.slice(0, a + START.length) + '\n' + bar + '\n' + s.slice(b);
  fs.writeFileSync(file, s);
  console.log('footer: Home / Orders / Reports / Products / Menu');
})();

console.log('ADMIN NAV + FOOTER OK');
