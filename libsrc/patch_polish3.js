'use strict';
/* Admin polish (batch 3): correct the misleading "SMTP" wording in Marketing (the site
   sends via Brevo), and trim AI-sounding text in Labels, Order detail and Products.
   Skip-on-miss: an anchor that isn't present (e.g. a view already changed on live) is
   logged and skipped, never aborting. Operates on the live views/routes. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_polish3.js <ROOT>'); process.exit(1); }

function edit(rel, items) {
  const file = path.join(ROOT, rel);
  let s; try { s = fs.readFileSync(file, 'utf8'); } catch (e) { console.log('skip (no file): ' + rel); return; }
  let changed = false;
  for (const [find, repl, name] of items) {
    if (s.indexOf(repl) >= 0 && repl.length > 8) { console.log('skip (already): ' + rel + ' :: ' + name); continue; }
    const i = s.indexOf(find);
    if (i < 0) { console.log('skip (not found): ' + rel + ' :: ' + name); continue; }
    s = s.slice(0, i) + repl + s.slice(i + find.length); changed = true;
    console.log('trimmed: ' + rel + ' :: ' + name);
  }
  if (changed) fs.writeFileSync(file, s);
}

edit('views/admin/marketing.ejs', [
  ["Email (SMTP) isn't configured yet, so sends won't go out. Set your SMTP env vars first.",
   "Email isn't configured yet, so promos won't send — set BREVO_API_KEY and GSZ_SMTP_FROM, then restart.", 'brevo wording']
]);
edit('routes/marketing.js', [
  ['Email (SMTP) is not configured, so nothing was sent.', 'Email is not configured, so nothing was sent.', 'brevo wording']
]);
edit('views/admin/labels.ejs', [
  ['No products with version options are mapped yet. Once a product has a bot plan offering more than one version (like Family / Adult), it appears here.',
   'No products with version options yet.', 'empty state'],
  ['Rename the version options customers see (e.g. show <b>Adult (XXX)</b> as <b>Adult 18+</b>). Leave a box blank to keep the default.',
   'Rename the version options customers see — leave a box blank to keep the default.', 'intro']
]);
edit('views/admin/order_detail.ejs', [
  ['“Deliver &amp; notify” marks the order delivered, messages the customer on WhatsApp and emails their order with the details above. Use it for vendor-invite orders the bot can’t auto-close.',
   'Marks the order delivered, messages the customer on WhatsApp and emails their order.', 'deliver note']
]);
edit('views/admin/products.ejs', [
  ['Add a button to all selected products, or edit / delete / hide one that already exists on them.',
   'Add, edit, delete or hide a download button on the selected products.', 'bulk hint']
]);

console.log('POLISH3 OK');
