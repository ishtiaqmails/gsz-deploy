'use strict';
/* Fix: plan.required_fields should derive from the bot product's delivery_type (MAC / activation
   email / link+qty) — not its raw `needs` (which holds internal mapping params like plan_key/type).
   Targets the block inserted by patch_prodmodel.js in routes/adminCatalog.js. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_reqfields.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/adminCatalog.js');
let s = fs.readFileSync(file, 'utf8');

const OLD = "          const bp = (await c.query('SELECT needs FROM bot_products WHERE sku=$1', [bot_sku])).rows[0];\n          if (bp && Array.isArray(bp.needs)) reqf = bp.needs;";
const NEW = "          const bp = (await c.query('SELECT delivery_type FROM bot_products WHERE sku=$1', [bot_sku])).rows[0];\n" +
  "          const _RF = { hotplayer:[{key:'mac',label:'MAC address'}], ibosol:[{key:'mac',label:'MAC address'}], zayron:[{key:'mac',label:'MAC address'}], vendor_invite:[{key:'email',label:'Activation email'}], amember:[{key:'email',label:'Activation email'}], portal:[{key:'email',label:'Activation email'}], smm:[{key:'link',label:'Link'},{key:'qty',label:'Quantity'}] };\n" +
  "          if (bp) reqf = _RF[(bp.delivery_type||'').toLowerCase()] || [];";

if (s.indexOf("_RF[(bp.delivery_type") >= 0) { console.log('reqfields: already fixed (skip)'); }
else if (s.indexOf(OLD) >= 0) { s = s.replace(OLD, NEW); fs.writeFileSync(file, s); console.log('reqfields: required_fields now from delivery_type'); }
else { console.log('reqfields: anchor missing (skip)'); }
console.log('REQFIELDS OK');
