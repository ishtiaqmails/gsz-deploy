'use strict';
/* Website -> bot: send source/orderNo/storeContact on both submit-order payloads so the
   bot renders the premium aMember card for WEBSITE orders only (source=gsz_website).
   storeContact is pulled live from wa_settings.wa_sales_number, formatted as +<digits>. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_ampayload.js <ROOT>'); process.exit(1); }
function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    const first = s.indexOf(e.find);
    if (first < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
    if (s.indexOf(e.find, first + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
    s = s.slice(0, first) + e.replace + s.slice(first + e.find.length);
    console.log('patched: ' + rel + ' :: ' + e.name);
  }
  fs.writeFileSync(file, s);
}

patch('routes/checkout.js', [
  {
    name: 'store-contact-helper',
    guard: 'function _gszStoreContact',
    find: "  const wanotify = require('../lib/wanotify')(pool);\n",
    replace: "  const wanotify = require('../lib/wanotify')(pool);\n"
      + "  async function _gszStoreContact(){ try { const r = await pool.query(\"SELECT value FROM wa_settings WHERE key='wa_sales_number'\"); const v = r.rows[0] && r.rows[0].value ? String(r.rows[0].value).replace(/[^0-9]/g,'') : ''; return v ? ('+'+v) : ''; } catch(e){ return ''; } }\n"
  },
  {
    name: 'single-website-fields',
    guard: "source: 'gsz_website',\n          orderNo: o.order_no",
    find: "          deliveryType: _dt,\n",
    replace: "          deliveryType: _dt,\n"
      + "          source: 'gsz_website',\n"
      + "          orderNo: o.order_no || '',\n"
      + "          storeContact: await _gszStoreContact(),\n"
  },
  {
    name: 'cart-website-fields',
    guard: "source: 'gsz_website',\n              orderNo:",
    find: "              deliveryType: it.deliveryType || null,\n",
    replace: "              deliveryType: it.deliveryType || null,\n"
      + "              source: 'gsz_website',\n"
      + "              orderNo: (o.order_no || ''),\n"
      + "              storeContact: await _gszStoreContact(),\n"
  }
]);
console.log('AMPAYLOAD PATCH OK');
